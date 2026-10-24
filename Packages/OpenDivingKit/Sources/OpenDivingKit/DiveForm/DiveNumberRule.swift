/// A new dive's number, which is a suggestion either way and the diver's to change: the
/// server's answer to `GET /dives/next-number` while it answers, and the phone's own guess
/// while it cannot.
public enum DiveNumberRule {
  /// Offline, the server's own positional rule applied to a dive dated now: the highest number
  /// the phone has seen, plus the creates queued since, plus one; nil when it has seen none.
  /// Duplicates are allowed, and the web's numbering card tidies them afterwards.
  public static func offlineSuggestion(highestKnown: Int?, queuedCreates: Int) -> Int? {
    highestKnown.map { $0 + queuedCreates + 1 }
  }

  /// The web's note beside a suggested number some dive already carries; nil when none does.
  /// Shown while the field still holds that number.
  public static func takenNotice(_ suggestion: DiveNumberSuggestion) -> String? {
    guard suggestion.isTaken else { return nil }
    return "Another dive is already numbered #\(suggestion.diveNumber). "
      + "That's expected while back-filling a log - you can tidy the "
      + "numbering from the dive list once everything is in."
  }
}
