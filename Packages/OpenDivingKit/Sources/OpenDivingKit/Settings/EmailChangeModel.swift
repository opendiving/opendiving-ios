import Foundation
import Observation

/// *Account*'s email: the address is shown, and a new one is sent a confirmation link, which is
/// confirmed in a browser on the web's page. The session is untouched by the change; the new
/// address shows once the account is read again, which a settings screen does each time the
/// app returns to the foreground. A direct call, online only.
@MainActor
@Observable
public final class EmailChangeModel {
  /// How long the link lasts, as the web says it.
  public static let linkLifetime = "30 minutes"
  public static let invalidAddress = "Please enter a valid email address"

  public private(set) var newEmail = ""
  public private(set) var isSending = false
  /// Why the address was not sent: the form's refusal or the API's sentence.
  public private(set) var failure: String?
  /// The address the last link went to.
  private var sentTo: String?

  @ObservationIgnored private let session: Session

  public init(session: Session) {
    self.session = session
  }

  public var currentEmail: String? { session.user?.email }

  public func setNewEmail(_ text: String) {
    newEmail = text
    failure = nil
  }

  public var canSend: Bool {
    !isSending && !newEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  /// Where the link went and how long it lasts, until the account holds that address.
  public var sentMessage: String? {
    guard let sentTo, currentEmail?.lowercased() != sentTo.lowercased() else { return nil }
    return "We sent a confirmation link to \(sentTo). Open it to finish changing your email — it"
      + " expires in \(Self.linkLifetime)."
  }

  /// Sends the typed address a confirmation link. The field empties once it is sent; a refusal
  /// keeps it.
  public func send() async {
    guard canSend else { return }
    let address = newEmail.trimmingCharacters(in: .whitespacesAndNewlines)
    guard Self.isAddress(address) else {
      failure = Self.invalidAddress
      return
    }
    failure = nil
    isSending = true
    defer { isSending = false }
    do {
      try await session.routedClient().requestEmailChange(to: address)
      sentTo = address
      newEmail = ""
    } catch {
      failure = APIError(error).message
    }
  }

  /// One `@` with something on each side, a dot inside the domain, and no spaces: enough to
  /// catch a typo before the server's own check.
  static func isAddress(_ text: String) -> Bool {
    let parts = text.split(separator: "@", omittingEmptySubsequences: false)
    guard parts.count == 2, !parts[0].isEmpty, !text.contains(where: \.isWhitespace) else {
      return false
    }
    let domain = parts[1].split(separator: ".", omittingEmptySubsequences: false)
    return domain.count >= 2 && domain.allSatisfy { !$0.isEmpty }
  }
}
