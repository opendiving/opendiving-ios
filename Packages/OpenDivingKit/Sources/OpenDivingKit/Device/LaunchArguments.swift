import Foundation

/// What the app reads from its command line, which only a developer's launch sets — the walk
/// with the phone that makes iOS relaunch the app, and a simulator's launch that starts signed
/// in or is handed a link.
public struct LaunchArguments: Hashable, Sendable {
  /// Ends the app a few seconds after it leaves the foreground, as iOS ending it would.
  public static let endInBackground = "--end-in-background"

  /// Ends the app once a walk has kept its first dive, as iOS ending it mid-download would.
  public static let endAfterFirstDive = "--end-after-first-dive"

  /// The server a simulator's launch starts on: the origin is the argument after it.
  public static let server = "--server"

  /// The session that launch starts with: the refresh token is the argument after it.
  public static let refreshToken = "--refresh-token"

  /// An address a simulator's launch is handed as a link from outside, since a simulator build
  /// has no associated domain to follow one by: the address is the argument after it.
  public static let link = "--link"

  public var endsInBackground: Bool
  public var endsAfterFirstDive: Bool
  /// Nil unless both ``server`` and ``refreshToken`` are given, each with a value it can read.
  public var signIn: LaunchSignIn?
  /// The address after ``link``, where it reads as one.
  public var link: URL?

  /// `arguments` as the process received them, its path first.
  public init(_ arguments: [String]) {
    let given = Array(arguments.dropFirst())
    endsInBackground = given.contains(Self.endInBackground)
    endsAfterFirstDive = given.contains(Self.endAfterFirstDive)
    func value(after flag: String) -> String? {
      guard let index = given.firstIndex(of: flag), index + 1 < given.count else { return nil }
      return given[index + 1]
    }
    if let origin = value(after: Self.server).flatMap({ ServerOrigin($0) }),
      let token = value(after: Self.refreshToken), !token.isEmpty
    {
      signIn = LaunchSignIn(origin: origin, refreshToken: token)
    }
    self.link = value(after: Self.link).flatMap(AppLink.url(given:))
  }
}
