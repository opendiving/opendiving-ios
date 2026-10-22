import Foundation
import OpenDivingKit
import Testing

@testable import OpenDiving

/// Over a real `URLSession` built from the app's configuration, with the answers stubbed
/// beneath it. What this proves end to end is that the refresh token reaches the secret store
/// off `Set-Cookie`, and that no response lands in the shared cache, which `forget` cannot
/// reach. Its cookie-jar assertion is weaker: `URLSession` leaves a stubbed protocol's
/// `Set-Cookie` out of the jar even with cookies on, so the jar being off is asserted on the
/// transport's configuration itself, in the Kit's `URLSessionTransportTests`.
@MainActor
struct CookieAndCacheTests {
  @Test func signingInAndFetchingBytesLeaveNoCookieAndNoCachedResponse() async throws {
    let origin = try #require(ServerOrigin("https://cookie-\(UUID().uuidString.prefix(8)).invalid"))
    let configuration = NetworkConfiguration.make()
    configuration.protocolClasses = [StubURLProtocol.self] + (configuration.protocolClasses ?? [])
    let secrets = InMemorySecretStore()
    let client = APIClient(
      origin: origin, transport: URLSessionTransport(configuration: configuration),
      secrets: secrets, background: NoBackgroundExecution(), userAgent: .device)

    let outcome = try await client.verifyEmailCode(requestID: UUID(), code: "123456")
    #expect(outcome.status == "authenticated")
    #expect(try secrets.secret(for: origin.description) == "from-the-wire")

    let portrait = try await client.portrait(version: "abc", etag: nil)
    guard case .fetched(let bytes, let etag) = portrait else {
      Issue.record("Expected the portrait's bytes")
      return
    }
    #expect(bytes.data.count == 4)
    #expect(etag == "\"portrait-1\"")

    #expect(HTTPCookieStorage.shared.cookies(for: origin.url)?.isEmpty ?? true)
    #expect(HTTPCookieStorage.shared.cookies(for: origin.apiBaseURL)?.isEmpty ?? true)
    let portraitURL = origin.apiBaseURL.appendingPathComponent("user/portrait")
    var components = try #require(
      URLComponents(url: portraitURL, resolvingAgainstBaseURL: false))
    components.queryItems = [URLQueryItem(name: "v", value: "abc")]
    let request = URLRequest(url: try #require(components.url))
    #expect(URLCache.shared.cachedResponse(for: request) == nil)
  }
}
