import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum APIError: LocalizedError, Equatable, Sendable {
    case invalidServerURL, invalidRequest, invalidResponse, invalidData
    case signInRejected, sessionExpired, forbidden, notFound, conflict, rateLimited
    case server(Int)

    public var errorDescription: String? {
        switch self {
        case .invalidServerURL: "The DelivMy server URL is not valid. Use an HTTPS server."
        case .invalidRequest: "This request could not be sent."
        case .invalidResponse: "The server returned an unexpected response."
        case .invalidData: "The app couldn’t read the server’s response. Check that the server is running the matching DelivMy API."
        case .signInRejected: "Couldn’t sign in. Check your email and password."
        case .sessionExpired: "Your session has ended. Please sign in again."
        case .forbidden: "You don’t have access to this request."
        case .notFound: "This request is no longer available."
        case .conflict: "This request changed and isn’t available for that action. Refresh and try again."
        case .rateLimited: "Too many attempts. Wait a moment before trying again."
        case .server(let status): "The server couldn’t complete this request (HTTP \(status))."
        }
    }
}

public struct APIClient: Sendable {
    public static let productionURL = URL(string: "https://delivmy.com/")!
    public let baseURL: URL
    private let transport: URLSession

    public init(baseURL: URL = productionURL, allowInsecureLoopback: Bool = false) throws {
        try self.init(baseURL: baseURL, allowInsecureLoopback: allowInsecureLoopback, transport: Self.makeTransport())
    }

    init(baseURL: URL, allowInsecureLoopback: Bool = false, transport: URLSession) throws {
        let host = baseURL.host?.lowercased()
        guard let host, !host.isEmpty, baseURL.user == nil, baseURL.password == nil,
              baseURL.query == nil, baseURL.fragment == nil else { throw APIError.invalidServerURL }
        switch baseURL.scheme?.lowercased() {
        case "https": break
        case "http" where allowInsecureLoopback && ["localhost", "127.0.0.1", "::1", "[::1]"].contains(host): break
        default: throw APIError.invalidServerURL
        }
        self.baseURL = baseURL
        self.transport = transport
    }

    public var signUpURL: URL { baseURL.appendingPathComponent("signup") }

    // Only open server-owned images from the origin configured for this build.
    // Do not add the user's bearer token to resource links.
    public func mediaURL(_ value: String?) -> URL? {
        guard let value, !value.isEmpty,
              let url = URL(string: value, relativeTo: baseURL.appendingPathComponent("", isDirectory: true))?.absoluteURL,
              url.user == nil, url.password == nil,
              url.scheme?.lowercased() == baseURL.scheme?.lowercased(),
              url.host?.lowercased() == baseURL.host?.lowercased(),
              (url.port ?? (url.scheme == "https" ? 443 : 80))
                == (baseURL.port ?? (baseURL.scheme == "https" ? 443 : 80)) else { return nil }
        return url
    }

    public func imageData(at url: URL) async throws -> Data {
        guard mediaURL(url.absoluteString) != nil else { throw APIError.invalidRequest }
        let (data, response) = try await transport.data(from: url)
        guard let response = response as? HTTPURLResponse, (200...299).contains(response.statusCode),
              response.mimeType?.hasPrefix("image/") == true, data.count <= 5_000_000 else {
            throw APIError.invalidResponse
        }
        return data
    }

    public func login(email: String, password: String) async throws -> AuthSession {
        struct Credentials: Encodable { let email: String; let password: String }
        struct Body: Encodable { let session: Credentials }
        struct Response: Decodable { let session: AuthSession }
        let body = try JSONEncoder().encode(Body(session: Credentials(email: email, password: password)))
        let data = try await send(.post, ["login"], body: body, isLogin: true)
        return try decode(Response.self, from: data).session
    }

    public func logout(session: AuthSession) async throws {
        _ = try await send(.delete, ["logout"], session: session)
    }

    public func nearby(_ bounds: SearchBounds, session: AuthSession) async throws -> [DeliveryRequest] {
        let query = [
            URLQueryItem(name: "sw", value: bounds.southwest.queryValue),
            URLQueryItem(name: "ne", value: bounds.northeast.queryValue),
            URLQueryItem(name: "center", value: bounds.center.queryValue)
        ]
        let data = try await send(.get, ["search"], query: query, session: session)
        return try decode([DeliveryRequest].self, from: data)
    }

    public func requests(session: AuthSession) async throws -> [DeliveryRequest] {
        let data = try await send(.get, ["requests"], session: session)
        return try decode([DeliveryRequest].self, from: data)
    }

    public func deliveries(session: AuthSession) async throws -> [DeliveryRequest] {
        let data = try await send(.get, ["delivers"], session: session)
        return try decode([DeliveryRequest].self, from: data)
    }

    public func items(requestID: Int, session: AuthSession) async throws -> [DeliveryItem] {
        let data = try await send(.get, ["requests", String(requestID), "items"], session: session)
        return try decode([DeliveryItem].self, from: data)
    }

    public func location(requestID: Int, session: AuthSession) async throws -> DeliveryLocation? {
        let data = try await send(.get, ["requests", String(requestID), "locations"], session: session)
        return try decode(DeliveryLocation?.self, from: data)
    }

    public func accept(requestID: Int, session: AuthSession) async throws {
        struct Body: Encodable {
            let requestID: Int
            private enum CodingKeys: String, CodingKey { case requestID = "request_id" }
        }
        let data = try JSONEncoder().encode(Body(requestID: requestID))
        struct Response: Decodable { let message: String }
        let response = try await send(.post, ["delivers", "new"], body: data, session: session)
        guard !response.isEmpty else { return }
        guard !(try decode(Response.self, from: response).message).isEmpty else { throw APIError.invalidData }
    }

    public func delete(requestID: Int, session: AuthSession) async throws {
        _ = try await send(.delete, ["requests", String(requestID)], session: session)
    }

    private enum Verb: String { case get = "GET", post = "POST", delete = "DELETE" }

    private func send(
        _ verb: Verb,
        _ path: [String],
        query: [URLQueryItem] = [],
        body: Data? = nil,
        session: AuthSession? = nil,
        isLogin: Bool = false
    ) async throws -> Data {
        let url = path.reduce(baseURL) { $0.appendingPathComponent($1) }
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidRequest
        }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw APIError.invalidRequest }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.httpMethod = verb.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpShouldHandleCookies = false
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let session {
            guard !session.token.isEmpty, session.token.utf8.allSatisfy({ (33...126).contains($0) }) else {
                throw APIError.invalidRequest
            }
            request.setValue("Bearer \(session.token)", forHTTPHeaderField: "Authorization")
        }
        let (data, rawResponse) = try await transport.data(for: request)
        guard let response = rawResponse as? HTTPURLResponse else { throw APIError.invalidResponse }
        switch response.statusCode {
        case 204: return data
        case 200...299:
            guard let mime = response.mimeType?.lowercased(),
                  mime == "application/json" || mime.hasSuffix("+json") else { throw APIError.invalidResponse }
            return data
        case 400 where isLogin, 401 where isLogin, 422 where isLogin: throw APIError.signInRejected
        case 401: throw APIError.sessionExpired
        case 403: throw APIError.forbidden
        case 404: throw APIError.notFound
        case 409: throw APIError.conflict
        case 429: throw APIError.rateLimited
        default: throw APIError.server(response.statusCode)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer()
            let text = try value.decode(String.self)
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let parsed = iso.date(from: text) { return parsed }
            iso.formatOptions = [.withInternetDateTime]
            if let parsed = iso.date(from: text) { return parsed }
            throw DecodingError.dataCorruptedError(in: value, debugDescription: "Invalid ISO 8601 date.")
        }
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw APIError.invalidData
        }
    }

    private static func makeTransport() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 30
        config.httpCookieAcceptPolicy = .never
        config.httpShouldSetCookies = false
        config.urlCache = nil
        return URLSession(configuration: config, delegate: RefuseRedirects(), delegateQueue: nil)
    }
}

private final class RefuseRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        // Do not follow HTTP redirects that could replay a password or bearer token.
        completionHandler(nil)
    }
}
