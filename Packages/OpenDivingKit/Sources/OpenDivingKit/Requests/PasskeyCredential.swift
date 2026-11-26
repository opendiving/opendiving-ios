import Foundation

/// A credential as the JSON WebAuthn gives a browser's answer, which is what the API's library
/// parses: every byte string base64url with no padding, `id` the same as `rawId`, and an empty
/// `clientExtensionResults`, which the specification requires. Its members keep the
/// specification's spelling, so it is never encoded with ``APICoding``'s snake_case keys:
/// ``PasskeySignInVerifyRequest/body()`` and ``PasskeyRegistrationVerifyRequest/body()`` send it.
public struct PasskeyCredential: Codable, Hashable, Sendable {
  public let id: String
  public let rawId: String
  public let type: String
  public let response: Response
  public let authenticatorAttachment: String?
  public let clientExtensionResults: [String: String]

  /// A sign-in's members, or a new passkey's.
  public struct Response: Codable, Hashable, Sendable {
    public let clientDataJSON: String
    public let authenticatorData: String?
    public let signature: String?
    /// The account's id the passkey was made under, as the options named it.
    public let userHandle: String?
    public let attestationObject: String?
  }

  public init(_ assertion: PasskeyAssertion) {
    self.init(
      credentialID: assertion.credentialID, attachment: assertion.attachment,
      response: Response(
        clientDataJSON: Base64URL.encode(assertion.clientDataJSON),
        authenticatorData: Base64URL.encode(assertion.authenticatorData),
        signature: Base64URL.encode(assertion.signature),
        userHandle: Base64URL.encode(assertion.userID), attestationObject: nil))
  }

  public init(_ registration: PasskeyRegistration) {
    self.init(
      credentialID: registration.credentialID, attachment: registration.attachment,
      response: Response(
        clientDataJSON: Base64URL.encode(registration.clientDataJSON), authenticatorData: nil,
        signature: nil, userHandle: nil,
        attestationObject: Base64URL.encode(registration.attestationObject)))
  }

  private init(credentialID: Data, attachment: PasskeyAttachment?, response: Response) {
    id = Base64URL.encode(credentialID)
    rawId = id
    type = "public-key"
    self.response = response
    authenticatorAttachment = attachment?.rawValue
    clientExtensionResults = [:]
  }
}
