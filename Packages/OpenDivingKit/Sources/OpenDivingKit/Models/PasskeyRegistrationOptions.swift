import Foundation

/// `POST /user/passkey/options`: what the system needs to make a passkey for the signed-in
/// account. `options` is an untyped map in the API's document; these are the members the phone
/// reads of WebAuthn's creation options, which keep the specification's spelling.
public struct PasskeyRegistrationOptions: Codable, Hashable, Sendable {
  public let options: Options

  public struct Options: Codable, Hashable, Sendable {
    public let challenge: String
    public let rp: RelyingParty
    public let user: User
    public let excludeCredentials: [PasskeyCredentialDescriptor]?
    public let authenticatorSelection: AuthenticatorSelection?
  }

  public struct RelyingParty: Codable, Hashable, Sendable {
    public let id: String
  }

  public struct User: Codable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let displayName: String
  }

  public struct AuthenticatorSelection: Codable, Hashable, Sendable {
    public let userVerification: String?
  }

  /// What the system is handed, or nil when the challenge, the account's id or an excluded
  /// credential's id is not base64url.
  public var request: PasskeyRegistrationRequest? {
    guard let challenge = Base64URL.decode(options.challenge),
      let userID = Base64URL.decode(options.user.id)
    else { return nil }
    let excluded = (options.excludeCredentials ?? []).map { Base64URL.decode($0.id) }
    guard !excluded.contains(nil) else { return nil }
    return PasskeyRegistrationRequest(
      relyingParty: options.rp.id, challenge: challenge, userID: userID, name: options.user.name,
      displayName: options.user.displayName,
      userVerification: options.authenticatorSelection?.userVerification,
      excludedCredentials: excluded.compactMap { $0 })
  }
}
