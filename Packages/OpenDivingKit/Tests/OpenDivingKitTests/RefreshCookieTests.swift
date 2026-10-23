import Foundation
import OpenDivingKit
import Testing

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Over the client, because the parser is internal: a sign-in whose `Set-Cookie` is spelled
/// one way or another lands that value in the store, or nothing.
struct RefreshCookieTests {
  private func storedAfterSignIn(setCookie: String?) async throws -> String? {
    let harness = ClientHarness(refreshToken: nil) { _ in
      .json(
        try KitFixture.text("auth-outcome-authenticated"),
        headers: setCookie.map { ["Set-Cookie": $0] } ?? [:])
    }
    _ = try await harness.client.verifyEmailCode(requestID: UUID(), code: "123456")
    return harness.storedRefreshToken
  }

  @Test(arguments: [
    ("refresh_token=abc.def.ghi; HttpOnly; Max-Age=604800; Path=/; SameSite=lax", "abc.def.ghi"),
    (
      "refresh_token=abc.def.ghi; expires=Wed, 29 Oct 2026 10:00:00 GMT; HttpOnly; Secure; Path=/",
      "abc.def.ghi"
    ),
    ("theme=dark; Path=/, refresh_token=abc.def.ghi; HttpOnly", "abc.def.ghi"),
    ("my_refresh_token=nope; Path=/", nil),
    ("refresh_token=\"\"; expires=Thu, 01 Jan 1970 00:00:00 GMT; Max-Age=0; Path=/", nil),
  ])
  func readsTheRefreshTokenOffSetCookie(header: String, expected: String?) async throws {
    #expect(try await storedAfterSignIn(setCookie: header) == expected)
  }

  @Test func noSetCookieStoresNothing() async throws {
    #expect(try await storedAfterSignIn(setCookie: nil) == nil)
  }
}
