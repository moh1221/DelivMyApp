import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import DelivMyCore

@Suite(.serialized)
struct APIClientTests {
    let server = URL(string: "https://delivmy.example/")!
    let session = AuthSession(token: "test-bearer", userID: "user-42")

    @Test func loginUsesNestedCredentialsAndReadsStringOrNumericUserID() async throws {
        let client = try stub { request in
            #expect(request.url?.path == "/login")
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
            let data = try #require(request.httpBody)
            let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: [String: String]])
            #expect(body == ["session": ["email": "example@invalid.test", "password": "test-password"]])
            return StubReply(200, #"{"session":{"id":"new-token","user_id":42}}"#)
        }
        let signedIn = try await client.login(email: "example@invalid.test", password: "test-password")
        #expect(signedIn.token == "new-token")
        #expect(signedIn.userID == "42")
        let uuid = try JSONDecoder().decode(AuthSession.self, from: Data(#"{"id":"a-token","user_id":"uuid-123456"}"#.utf8))
        #expect(uuid.userID == "uuid-123456")
    }

    @Test func nearbyUsesRailsQueryAndDecodesNestedNullableModels() async throws {
        let client = try stub { request in
            #expect(request.url?.path == "/search")
            #expect(request.httpMethod == "GET")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-bearer")
            #expect(request.value(forHTTPHeaderField: "Cookie") == nil)
            let pieces = try #require(request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) })
            let query = Dictionary(uniqueKeysWithValues: (pieces.queryItems ?? []).map { ($0.name, $0.value) })
            #expect(query == ["sw": "38.0,-78.0", "ne": "39.0,-77.0", "center": "38.5,-77.5"])
            return StubReply(200, """
                [
                  {"id":"123","PlaceName":"Store","status_id":1,"cost":"12.25","fees":5.50,
                   "delivery_at":"2099-01-01T13:05:09.123Z","category":{"CatName":"Grocery"},
                   "profile":{"first_name":"Jo","last_name":null,"picture":"/uploads/profile.png"},
                   "location":{"Lat":38.5,"Long":"-77.5","address":null},"items":[{"id":22}]},
                  {"id":124,"status_id":99,"cost":null,"delivery_at":null,"profile":null,
                   "deliver":{"receipt_img":null,"completed_at":"2020-01-01T13:00:00Z"}}
                ]
                """)
        }
        let southwest = try #require(Coordinate(latitude: 38, longitude: -78))
        let northeast = try #require(Coordinate(latitude: 39, longitude: -77))
        let center = try #require(Coordinate(latitude: 38.5, longitude: -77.5))
        let bounds = try #require(SearchBounds(southwest: southwest, northeast: northeast, center: center))
        let rows = try await client.nearby(bounds, session: session)
        #expect(rows.map(\.id) == [123, 124])
        let first = try #require(rows.first)
        #expect(first.category == "Grocery")
        #expect(first.profile?.displayName == "Jo")
        #expect(first.location?.coordinate?.longitude == -77.5)
        #expect(first.cost == Decimal(string: "12.25"))
        #expect(first.fee == Decimal(string: "5.50"))
        #expect(first.items?.first?.name == nil)
        #expect(first.isAcceptable)
        #expect(rows.last?.status == .unknown)
        #expect(rows.last?.isAcceptable == false)
        #expect(rows.last?.delivery?.completedAt != nil)
    }

    @Test func listsDetailsAndMutationsKeepLegacyRoutes() async throws {
        let client = try stub { request in
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-bearer")
            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/requests"), ("GET", "/delivers"):
                return StubReply(200, #"[{"id":13,"PlaceName":"Bread","status_id":2}]"#)
            case ("GET", "/requests/13/items"):
                return StubReply(200, #"[{"id":45,"ItemsName":"Milk","ItemDescription":"Two bottles"}]"#)
            case ("GET", "/requests/13/locations"):
                return StubReply(200, "null")
            case ("POST", "/delivers/new"):
                let bodyData = try #require(request.httpBody)
                let json = try #require(JSONSerialization.jsonObject(with: bodyData) as? [String: Int])
                #expect(json == ["request_id": 13])
                return StubReply(200, #"{"message":"Success"}"#)
            case ("DELETE", "/requests/13"), ("DELETE", "/logout"):
                return StubReply(204, "")
            default:
                Issue.record("Unexpected API route")
                return StubReply(500, "{}")
            }
        }
        #expect(try await client.requests(session: session).first?.id == 13)
        #expect(try await client.deliveries(session: session).first?.status == .inProgress)
        #expect(try await client.items(requestID: 13, session: session).first?.notes == "Two bottles")
        #expect(try await client.location(requestID: 13, session: session) == nil)
        try await client.accept(requestID: 13, session: session)
        try await client.delete(requestID: 13, session: session)
        try await client.logout(session: session)
    }

    @Test func rejectsConflictExpiredSessionInvalidLoginAndHTML() async throws {
        let client = try stub { request in
            switch request.url?.path {
            case "/login": return StubReply(422, "{}")
            case "/delivers": return StubReply(401, "{}")
            case "/requests": return StubReply(200, "<html>Sign in</html>", mime: "text/html")
            default: return StubReply(409, "{}")
            }
        }
        await #expect(throws: APIError.signInRejected) {
            try await client.login(email: "someone@invalid.test", password: "invalid")
        }
        await #expect(throws: APIError.sessionExpired) { try await client.deliveries(session: session) }
        await #expect(throws: APIError.conflict) { try await client.delete(requestID: 2, session: session) }
        await #expect(throws: APIError.invalidResponse) { try await client.requests(session: session) }
    }

    @Test func malformedBodyAndMissingMutationConfirmationFailSafely() async throws {
        let client = try stub { request in
            if request.url?.path == "/delivers/new" { return StubReply(200, #"{"error":"No update"}"#) }
            return StubReply(200, #"[{"id":null}]"#)
        }
        await #expect(throws: APIError.invalidData) { try await client.requests(session: session) }
        await #expect(throws: APIError.invalidData) { try await client.accept(requestID: 20, session: session) }
    }

    @Test func serverURLPolicyAndMediaAreOriginScoped() throws {
        #expect(throws: APIError.invalidServerURL) {
            try APIClient(baseURL: URL(string: "http://not-local.example")!, allowInsecureLoopback: true)
        }
        #expect(throws: APIError.invalidServerURL) { try APIClient(baseURL: URL(string: "http://localhost")!) }
        #expect(throws: APIError.invalidServerURL) { try APIClient(baseURL: URL(string: "https://user:secret@localhost")!) }
        let local = try APIClient(baseURL: URL(string: "http://localhost:3000")!, allowInsecureLoopback: true)
        #expect(local.signUpURL.absoluteString == "http://localhost:3000/signup")
        let client = try APIClient(baseURL: server)
        #expect(client.mediaURL("/uploads/a.png")?.absoluteString == "https://delivmy.example/uploads/a.png")
        #expect(client.mediaURL("https://delivmy.example:443/uploads/a.png") != nil)
        #expect(client.mediaURL("https://delivmy.example:8443/uploads/a.png") == nil)
        #expect(client.mediaURL("//third-party.example/profile") == nil)
        #expect(client.mediaURL("http://delivmy.example/profile") == nil)
        #expect(client.mediaURL("https://user:password@delivmy.example/profile") == nil)
    }

    private func stub(_ handler: @escaping StubRegistry.Handler) throws -> APIClient {
        StubProtocol.registry.set(handler)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        return try APIClient(baseURL: server, transport: URLSession(configuration: config))
    }
}

private struct StubReply {
    let status: Int
    let body: String
    let mime: String

    init(_ status: Int, _ body: String, mime: String = "application/json") {
        self.status = status
        self.body = body
        self.mime = mime
    }
}

private final class StubRegistry: @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) throws -> StubReply
    private let lock = NSLock()
    private var handler: Handler?

    func set(_ handler: @escaping Handler) {
        lock.withLock { self.handler = handler }
    }

    func response(for request: URLRequest) throws -> StubReply {
        guard let handler = lock.withLock({ self.handler }) else { throw APIError.invalidRequest }
        return try handler(request)
    }
}

private final class StubProtocol: URLProtocol {
    static let registry = StubRegistry()

    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "delivmy.example" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            let stub = try Self.registry.response(for: request)
            guard let url = request.url, let response = HTTPURLResponse(
                url: url,
                statusCode: stub.status,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": stub.mime]
            ) else { throw APIError.invalidResponse }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(stub.body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
