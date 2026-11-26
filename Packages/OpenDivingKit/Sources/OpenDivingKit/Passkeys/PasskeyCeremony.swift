import Foundation

/// The system's passkey sheet. A protocol because the Kit builds where AuthenticationServices
/// does not exist: the app target conforms to it, and the Kit's tests use a fake.
///
/// One ceremony is out at a time. A request made while another is out replaces it, and the
/// replaced one ends as ``PasskeyCeremonyResult/dismissed``, as does one ``cancel()`` ends.
@MainActor
public protocol PasskeyCeremony: AnyObject {
  func signIn(_ request: PasskeySignInRequest) async -> PasskeyCeremonyResult<PasskeyAssertion>
  func register(_ request: PasskeyRegistrationRequest) async
    -> PasskeyCeremonyResult<PasskeyRegistration>
  /// Ends the ceremony that is out, if one is.
  func cancel()
}

/// How a ceremony ended.
public enum PasskeyCeremonyResult<Value: Hashable & Sendable>: Hashable, Sendable {
  case done(Value)
  /// The diver closed the sheet, or another request replaced this one. Nothing is said.
  case dismissed
  /// The passkey manager already holds one of the credentials the registration excluded.
  case matchedExcludedCredential
  /// The system refused the ceremony: no association with the relying party, among others.
  case failed
}

/// Signing in, as the options of `POST /auth/passkey/options` give it.
public struct PasskeySignInRequest: Hashable, Sendable {
  /// The relying party the server's options name, never the server's address.
  public let relyingParty: String
  public let challenge: Data
  public let allowedCredentials: [Data]
  /// WebAuthn's `userVerification`, nil where the options give none.
  public let userVerification: String?
  /// Only a passkey the phone holds will do, so that the sheet shows nothing when it holds
  /// none: the sheet on arrival's request. The button asks for any, a nearby device's included.
  public let onlyOnThisPhone: Bool

  public init(
    relyingParty: String, challenge: Data, allowedCredentials: [Data], userVerification: String?,
    onlyOnThisPhone: Bool
  ) {
    self.relyingParty = relyingParty
    self.challenge = challenge
    self.allowedCredentials = allowedCredentials
    self.userVerification = userVerification
    self.onlyOnThisPhone = onlyOnThisPhone
  }
}

/// A new passkey, as the options of `POST /user/passkey/options` give it.
public struct PasskeyRegistrationRequest: Hashable, Sendable {
  public let relyingParty: String
  public let challenge: Data
  public let userID: Data
  public let name: String
  public let displayName: String
  public let userVerification: String?
  /// The account's passkeys, which the passkey manager is asked not to make again.
  public let excludedCredentials: [Data]

  public init(
    relyingParty: String, challenge: Data, userID: Data, name: String, displayName: String,
    userVerification: String?, excludedCredentials: [Data]
  ) {
    self.relyingParty = relyingParty
    self.challenge = challenge
    self.userID = userID
    self.name = name
    self.displayName = displayName
    self.userVerification = userVerification
    self.excludedCredentials = excludedCredentials
  }
}

/// Where the authenticator was, as WebAuthn spells it.
public enum PasskeyAttachment: String, Hashable, Sendable {
  case platform
  case crossPlatform = "cross-platform"
}

/// What the system returns for a sign-in, raw.
public struct PasskeyAssertion: Hashable, Sendable {
  public let credentialID: Data
  public let clientDataJSON: Data
  public let authenticatorData: Data
  public let signature: Data
  public let userID: Data
  public let attachment: PasskeyAttachment?

  public init(
    credentialID: Data, clientDataJSON: Data, authenticatorData: Data, signature: Data,
    userID: Data, attachment: PasskeyAttachment?
  ) {
    self.credentialID = credentialID
    self.clientDataJSON = clientDataJSON
    self.authenticatorData = authenticatorData
    self.signature = signature
    self.userID = userID
    self.attachment = attachment
  }
}

/// What the system returns for a new passkey, raw.
public struct PasskeyRegistration: Hashable, Sendable {
  public let credentialID: Data
  public let clientDataJSON: Data
  public let attestationObject: Data
  public let attachment: PasskeyAttachment?

  public init(
    credentialID: Data, clientDataJSON: Data, attestationObject: Data,
    attachment: PasskeyAttachment?
  ) {
    self.credentialID = credentialID
    self.clientDataJSON = clientDataJSON
    self.attestationObject = attestationObject
    self.attachment = attachment
  }
}
