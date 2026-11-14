/// What the app reads from its command line, which only a developer's launch sets — the walk
/// with the phone that makes iOS relaunch the app.
public struct LaunchArguments: Hashable, Sendable {
  /// Ends the app a few seconds after it leaves the foreground, as iOS ending it would.
  public static let endInBackground = "--end-in-background"

  /// Ends the app once a walk has kept its first dive, as iOS ending it mid-download would.
  public static let endAfterFirstDive = "--end-after-first-dive"

  public var endsInBackground: Bool
  public var endsAfterFirstDive: Bool

  /// `arguments` as the process received them, its path first.
  public init(_ arguments: [String]) {
    endsInBackground = arguments.dropFirst().contains(Self.endInBackground)
    endsAfterFirstDive = arguments.dropFirst().contains(Self.endAfterFirstDive)
  }
}
