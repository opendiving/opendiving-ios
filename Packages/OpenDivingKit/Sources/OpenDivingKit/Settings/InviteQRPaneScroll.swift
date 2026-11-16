/// The invite link pane's two places to rest: the QR code at the top, and the invitations at the
/// fold, the height of the pane below it. Between them a scroll never stops; below the fold it is
/// free.
public enum InviteQRPaneScroll {
  /// How far a drag has to carry the pane from where it rests before it settles at the other end.
  public static let threshold = 60.0

  /// How far the pane has come from the QR code to the invitations, from 0 to 1.
  public static func progress(offset: Double, fold: Double) -> Double {
    guard fold > 0 else { return 0 }
    return min(max(offset / fold, 0), 1)
  }

  /// Where a scroll that began at `start` and is headed for `proposed` comes to rest: past the
  /// threshold, the end it moves towards; short of it, the end it left; below the fold, where it
  /// was headed.
  public static func restingOffset(start: Double, proposed: Double, fold: Double) -> Double {
    guard proposed < fold else { return proposed }
    if proposed > start { return proposed >= threshold ? fold : 0 }
    if proposed < start { return proposed <= fold - threshold ? 0 : fold }
    return proposed < fold / 2 ? 0 : fold
  }
}
