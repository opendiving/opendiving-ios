import Foundation

/// `POST /auth/passkey/options`: the challenge a sign-in answers, and the flow it is stored
/// under. `options` is an untyped map in the API's document; these are the members the phone
/// reads of WebAuthn's assertion options, which keep the specification's spelling.
public struct PasskeySignInOptions: Codable, Hashable, Sendable {
  public let flowId: String
  public let options: Options

  public struct Options: Codable, Hashable, Sendable {
    public let challenge: String
    public let rpId: String
    public let allowCredentials: [PasskeyCredentialDescriptor]?
    public let userVerification: String?
  }

  /// What the system is handed, or nil when the challenge or a credential's id is not
  /// base64url.
  public func request(onlyOnThisPhone: Bool) -> PasskeySignInRequest? {
    guard let challenge = Base64URL.decode(options.challenge) else { return nil }
    let allowed = (options.allowCredentials ?? []).map { Base64URL.decode($0.id) }
    guard !allowed.contains(nil) else { return nil }
    return PasskeySignInRequest(
      relyingParty: options.rpId, challenge: challenge,
      allowedCredentials: allowed.compactMap { $0 },
      userVerification: options.userVerification, onlyOnThisPhone: onlyOnThisPhone)
  }
}

/// One of WebAuthn's credential descriptors, by its id alone.
public struct PasskeyCredentialDescriptor: Codable, Hashable, Sendable {
  public let id: String
  public let type: String
}
