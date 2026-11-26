import Foundation
import OpenDivingKit
import Testing

/// Which build offers a passkey on which server, and the bytes it sends.
@MainActor
struct PasskeyAssociationTests {
  @Test func theHostIsTheDomainLineWithoutItsMode() {
    #expect(PasskeyAssociation.host("opendiving.app") == "opendiving.app")
    #expect(PasskeyAssociation.host("Dive.Example.org?mode=developer") == "dive.example.org")
    #expect(PasskeyAssociation.host(nil) == nil)
    #expect(PasskeyAssociation.host("") == nil)
    #expect(PasskeyAssociation.host("?mode=developer") == nil)
  }

  @Test func aBuildWithNoHostHasNoAssociation() {
    #expect(PasskeyAssociation(domain: nil, ceremony: FakePasskeyCeremony()) == nil)
    #expect(PasskeyAssociation(domain: " ", ceremony: FakePasskeyCeremony()) == nil)
  }

  @Test(
    arguments: [
      // The association off.
      (nil, "https://dive.example.org", false),
      // A server on another host.
      ("dive.example.org", "https://opendiving.app", false),
      ("dive.example.org", "https://www.dive.example.org", false),
      // The build's host, whatever the scheme, the port and the case.
      ("dive.example.org", "https://dive.example.org", true),
      ("dive.example.org", "http://DIVE.example.org:8443", true),
      ("localhost", "http://localhost:8000", true),
    ] as [(String?, String, Bool)])
  func aPasskeyIsOfferedOnTheBuildsHostAlone(host: String?, server: String, offered: Bool) {
    let origin = ServerOrigin(server)!
    #expect(PasskeyAssociation.isOffered(buildHost: host, on: .signingIn(origin)) == offered)
    #expect(PasskeyAssociation.isOffered(buildHost: host, on: .signedIn(origin)) == offered)
  }

  @Test func withNoServerNothingIsOffered() {
    #expect(!PasskeyAssociation.isOffered(buildHost: "dive.example.org", on: .noServer))
  }

  @Test func base64URLReadsEitherPaddingAndWritesNone() {
    #expect(Base64URL.encode(Data([0xFB, 0xFF])) == "-_8")
    #expect(Base64URL.decode("-_8") == Data([0xFB, 0xFF]))
    #expect(Base64URL.decode("-_8=") == Data([0xFB, 0xFF]))
    #expect(Base64URL.decode("+/8=") == nil)
    #expect(Base64URL.decode("not base64url!") == nil)
  }

  @Test func anAssertionIsWebAuthnsJSON() throws {
    let sent = try JSONValue.parse(
      PasskeySignInVerifyRequest(
        flowId: "flow", credential: PasskeyCredential(FakePasskeyCeremony.assertion),
        idleTimeout: .extended
      ).body())
    let id = Base64URL.encode(FakePasskeyCeremony.assertion.credentialID)
    #expect(sent.keys == ["flow_id", "credential", "idle_timeout"])
    #expect(sent["idle_timeout"] == .string("extended"))
    let credential = try #require(sent["credential"])
    #expect(
      credential.keys == [
        "id", "rawId", "type", "response", "authenticatorAttachment", "clientExtensionResults",
      ])
    // The library refuses an `id` that is not the unpadded base64url of `rawId`.
    #expect(credential["id"] == .string(id))
    #expect(credential["rawId"] == .string(id))
    #expect(!id.contains("="))
    #expect(credential["type"] == .string("public-key"))
    #expect(credential["authenticatorAttachment"] == .string("platform"))
    #expect(credential["clientExtensionResults"] == .object([:]))
    let response = try #require(credential["response"])
    #expect(response.keys == ["clientDataJSON", "authenticatorData", "signature", "userHandle"])
    #expect(response["userHandle"] == .string("obI"))
    #expect(
      response["clientDataJSON"]
        == .string(Base64URL.encode(FakePasskeyCeremony.assertion.clientDataJSON)))
  }

  @Test func aNewPasskeyIsWebAuthnsJSON() throws {
    let registration = PasskeyRegistration(
      credentialID: Data([7]), clientDataJSON: Data([1]), attestationObject: Data([2]),
      attachment: .crossPlatform)
    let sent = try JSONValue.parse(
      PasskeyRegistrationVerifyRequest(
        credential: PasskeyCredential(registration), name: "iPhone"
      ).body())
    #expect(sent["name"] == .string("iPhone"))
    let credential = try #require(sent["credential"])
    #expect(credential["authenticatorAttachment"] == .string("cross-platform"))
    #expect(credential["response"]?.keys == ["clientDataJSON", "attestationObject"])
  }

  @Test func anAttachmentTheSystemDidNotGiveIsLeftOut() throws {
    let assertion = PasskeyAssertion(
      credentialID: Data([1]), clientDataJSON: Data([1]), authenticatorData: Data([1]),
      signature: Data([1]), userID: Data([1]), attachment: nil)
    let sent = try JSONValue.parse(
      PasskeySignInVerifyRequest(
        flowId: "flow", credential: PasskeyCredential(assertion), idleTimeout: .extended
      ).body())
    #expect(sent["credential"]?["authenticatorAttachment"] == nil)
  }
}
