import Foundation

/// A connect link on the flagship, opened while the app is on another server: the diver is
/// asked whether to switch to the flagship to open it there, the browser being the other answer.
/// The flagship alone is offered, being on every phone's list already, so a link never points
/// the app at a server the diver did not choose.
public struct FlagshipOffer: Hashable, Sendable {
  public let token: String
  /// The server the app is on.
  public let current: ServerOrigin
  /// Whether the phone is signed in to ``current``, where switching leaves it signed in.
  public let isSignedIn: Bool
  /// The link, for the browser.
  public let url: URL

  public init(token: String, current: ServerOrigin, isSignedIn: Bool, url: URL) {
    self.token = token
    self.current = current
    self.isSignedIn = isSignedIn
    self.url = url
  }

  /// What opens on the flagship.
  public var screen: AppLink.Screen { .connect(token: token) }

  public var sentence: String {
    "This connect link is for \(ServerOrigin.flagship), and the app is on \(current)"
      + (isSignedIn ? ", where you stay signed in." : ".")
  }

  public static let title = "Switch to \(ServerOrigin.flagship.host)?"
  public static let switchButton = "Switch to \(ServerOrigin.flagship.host)"
}
