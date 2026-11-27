import Foundation
import Testing
import DelivMyCore

private let localTestEnvironment = ProcessInfo.processInfo.environment
private let liveConfigured = ["DELIVMY_TEST_BASE_URL", "DELIVMY_TEST_EMAIL", "DELIVMY_TEST_PASSWORD"]
    .allSatisfy { !(localTestEnvironment[$0] ?? "").isEmpty }

@Test("DelivMy-Rails local login, lists, search and logout", .enabled(if: liveConfigured))
func localRailsContract() async throws {
    let base = try #require(localTestEnvironment["DELIVMY_TEST_BASE_URL"].flatMap { URL(string: $0) })
    // Never send disposable credentials to production or an external staging host.
    #expect(["localhost", "127.0.0.1", "::1", "[::1]"].contains(base.host?.lowercased() ?? ""))
    guard ["localhost", "127.0.0.1", "::1", "[::1]"].contains(base.host?.lowercased() ?? "") else {
        throw APIError.invalidServerURL
    }
    let email = try #require(localTestEnvironment["DELIVMY_TEST_EMAIL"])
    let password = try #require(localTestEnvironment["DELIVMY_TEST_PASSWORD"])
    let client = try APIClient(baseURL: base, allowInsecureLoopback: true)
    let session = try await client.login(email: email, password: password)
    do {
        _ = try await client.requests(session: session)
        _ = try await client.deliveries(session: session)
        let southwest = try #require(Coordinate(latitude: 38.935, longitude: -77.473))
        let northeast = try #require(Coordinate(latitude: 39.075, longitude: -77.333))
        let center = try #require(Coordinate(latitude: 39.005, longitude: -77.403))
        let bounds = try #require(SearchBounds(southwest: southwest, northeast: northeast, center: center))
        let nearby = try await client.nearby(bounds, session: session)
        if let id = nearby.first?.id {
            _ = try await client.items(requestID: id, session: session)
            _ = try await client.location(requestID: id, session: session)
        }
    } catch {
        try? await client.logout(session: session)
        throw error
    }
    try await client.logout(session: session)
    await #expect(throws: APIError.sessionExpired) { try await client.requests(session: session) }
}
