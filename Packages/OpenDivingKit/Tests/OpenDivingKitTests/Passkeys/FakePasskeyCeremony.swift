import Foundation
import OpenDivingKit

/// The system's sheet, answering what it is told to and recording what it was handed. An
/// answer held behind ``hold()`` waits until ``release()``, so a test can act while a
/// ceremony is out.
@MainActor
final class FakePasskeyCeremony: PasskeyCeremony {
  var signInAnswer = PasskeyCeremonyResult<PasskeyAssertion>.done(FakePasskeyCeremony.assertion)
  var registerAnswer = PasskeyCeremonyResult<PasskeyRegistration>.done(
    FakePasskeyCeremony.registration)
  private(set) var signIns: [PasskeySignInRequest] = []
  private(set) var registrations: [PasskeyRegistrationRequest] = []
  private(set) var cancels = 0
  private var held = false
  private var waiting: [CheckedContinuation<Void, Never>] = []

  static let assertion = PasskeyAssertion(
    credentialID: Data([1, 2, 3, 250]), clientDataJSON: Data(#"{"type":"webauthn.get"}"#.utf8),
    authenticatorData: Data([9, 8, 7]), signature: Data([6, 5, 4]), userID: Data([0xA1, 0xB2]),
    attachment: .platform)
  static let registration = PasskeyRegistration(
    credentialID: Data([1, 2, 3, 250]),
    clientDataJSON: Data(#"{"type":"webauthn.create"}"#.utf8), attestationObject: Data([0xA3]),
    attachment: .platform)

  /// The association a session is built with to offer passkeys on `host`.
  func association(_ host: String = "dive.example.org") -> PasskeyAssociation {
    PasskeyAssociation(domain: host, ceremony: self)!
  }

  func hold() { held = true }

  func release() {
    held = false
    let resumed = waiting
    waiting = []
    for continuation in resumed { continuation.resume() }
  }

  func signIn(_ request: PasskeySignInRequest) async -> PasskeyCeremonyResult<PasskeyAssertion> {
    signIns.append(request)
    await wait()
    return signInAnswer
  }

  func register(_ request: PasskeyRegistrationRequest) async
    -> PasskeyCeremonyResult<PasskeyRegistration>
  {
    registrations.append(request)
    await wait()
    return registerAnswer
  }

  func cancel() { cancels += 1 }

  private func wait() async {
    guard held else { return }
    await withCheckedContinuation { waiting.append($0) }
  }
}
