import Foundation

/// `POST /user/passkey/verify`'s body: the attestation, and the name the passkey is listed
/// under.
public struct PasskeyRegistrationVerifyRequest: Codable, Hashable, Sendable {
  public let credential: PasskeyCredential
  public let name: String

  public init(credential: PasskeyCredential, name: String) {
    self.credential = credential
    self.name = name
  }

  /// The body as sent: with the credential's members as WebAuthn spells them.
  public func body() throws -> Data {
    try PasskeyCredential.encoder.encode(self)
  }
}
