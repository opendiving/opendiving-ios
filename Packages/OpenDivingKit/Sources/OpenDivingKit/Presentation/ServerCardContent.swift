import Foundation

/// The server card in Settings, on a saved server's page and under the sign-in form: the
/// address, the build the server runs, and whether the connection is encrypted.
public struct ServerCardContent: Hashable, Sendable {
  /// The commit's length on the card: a short SHA, as GitHub prints one.
  public static let commitLength = 7

  public let address: String
  /// `0.6.0 (1a2b3c4)`, the version alone when the server does not know its commit, or
  /// `Unknown` when it has never answered — empty while it is first being asked.
  public let version: String
  public let isEncrypted: Bool
  /// The server is being asked what it runs; the version is the last answer until it replies.
  public let isUpdating: Bool
  /// Why the server could not be asked, the last time it was; the version is its last answer.
  public let updateFailure: String?

  /// `health` is what the server last answered, nil when it never has.
  public init(
    origin: ServerOrigin, health: HealthRead?, isUpdating: Bool = false,
    updateFailure: String? = nil
  ) {
    address = origin.description
    isEncrypted = origin.isEncrypted
    self.isUpdating = isUpdating
    self.updateFailure = isUpdating ? nil : updateFailure
    guard let health else {
      version = isUpdating ? "" : "Unknown"
      return
    }
    // `unknown` is what a build from outside the image pipeline reports.
    let commit = health.commit.trimmingCharacters(in: .whitespaces)
    if commit.isEmpty || commit == "unknown" {
      version = health.version
    } else {
      version = health.version + " (" + commit.prefix(Self.commitLength) + ")"
    }
  }
}
