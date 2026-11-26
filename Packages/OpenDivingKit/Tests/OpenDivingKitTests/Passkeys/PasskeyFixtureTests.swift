import Foundation
import OpenDivingKit
import Testing

/// The options the local API answered read into what the system is handed, the new passkey's
/// answer round-trips, and each verification body encodes, as sent, to its fixture exactly.
struct PasskeyFixtureTests {
  @Test func signInOptions() throws {
    let options = try KitFixture.roundTrip(PasskeySignInOptions.self, "passkey-sign-in-options")
    #expect(options.flowId == "ea599f0c-7b39-47d2-a84e-b3f33bc371d7")
    let request = try #require(options.request(onlyOnThisPhone: true))
    #expect(request.relyingParty == "localhost")
    #expect(request.challenge.count == 64)
    #expect(request.allowedCredentials.isEmpty)
    #expect(request.userVerification == "preferred")
    #expect(request.onlyOnThisPhone)
  }

  @Test func registrationOptions() throws {
    let options = try KitFixture.roundTrip(
      PasskeyRegistrationOptions.self, "passkey-registration-options")
    let request = try #require(options.request)
    #expect(request.relyingParty == "localhost")
    #expect(request.userID == Base64URL.decode("AaAh6azJeRi5QnFlQSHWPQ"))
    #expect(request.name == "sam@example.com")
    #expect(request.displayName == "Sam Rivera")
    #expect(request.userVerification == "preferred")
    #expect(
      request.excludedCredentials == [
        Base64URL.decode("KVx1mO-9KiREqgSai3fXq2HHQj_8c7qKXfkJnN4XpBg")!
      ]
    )
  }

  @Test func theNewPasskey() throws {
    let added = try KitFixture.roundTrip(PasskeyRead.self, "passkey-added")
    #expect(added.name == "iPhone")
    #expect(added.lastUsedAt == nil)
  }

  @Test func signInVerification() throws {
    let request = try sendsItsFixture(
      PasskeySignInVerifyRequest.self, "request-passkey-sign-in-verify"
    ) { try $0.body() }
    #expect(request.idleTimeout == .extended)
    #expect(request.credential.id == request.credential.rawId)
  }

  @Test func registrationVerification() throws {
    let request = try sendsItsFixture(
      PasskeyRegistrationVerifyRequest.self, "request-passkey-registration-verify"
    ) {
      try $0.body()
    }
    #expect(request.name == "iPhone")
  }

  /// Read with no key strategy, as the bodies are written.
  private func sendsItsFixture<Body: Decodable>(
    _ type: Body.Type, _ name: String, body: (Body) throws -> Data
  ) throws -> Body {
    let fixture = try KitFixture.data(name)
    let decoded = try JSONDecoder().decode(type, from: fixture)
    let sent = try JSONValue.parse(body(decoded))
    #expect(sent == (try JSONValue.parse(fixture)), "\(name): sent \(sent)")
    return decoded
  }
}
