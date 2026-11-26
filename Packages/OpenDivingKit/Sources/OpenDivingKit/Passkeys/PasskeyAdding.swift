import Foundation

/// Adding a passkey to the signed-in account: the options, the system's sheet with the
/// account's passkeys excluded, and the verification, the passkey named for the kind of
/// device. Settings and the offer after a sign-in both run it.
@MainActor
public enum PasskeyAdding {
  public enum Result: Hashable, Sendable {
    case added(PasskeyRead)
    /// The diver closed the sheet: nothing is said.
    case dismissed
    /// The phone's passkey manager already holds one for the account, which a second would
    /// replace there and leave listed here with nothing that can use it.
    case alreadyOnThisPhone
    /// The sentence to say: the API's where it gave one, the web's fallback where it did not.
    case failed(String)
  }

  public static let failed = "Couldn't add that passkey. Please try again."
  public static let alreadyOnThisPhone = "This phone already has a passkey for your account."

  public static func add(_ session: Session) async -> Result {
    guard let ceremony = session.passkeyCeremony else { return .failed(failed) }
    do {
      let client = try session.routedClient()
      guard let request = try await client.passkeyRegistrationOptions().request else {
        return .failed(failed)
      }
      switch await ceremony.register(request) {
      case .done(let registration):
        return .added(
          try await client.registerPasskey(
            PasskeyCredential(registration), name: session.deviceKind))
      case .dismissed:
        return .dismissed
      case .matchedExcludedCredential:
        return .alreadyOnThisPhone
      case .failed:
        return .failed(failed)
      }
    } catch is CancellationError {
      return .dismissed
    } catch {
      guard case .http(_, let message?) = APIError(error) else { return .failed(failed) }
      return .failed(message)
    }
  }
}
