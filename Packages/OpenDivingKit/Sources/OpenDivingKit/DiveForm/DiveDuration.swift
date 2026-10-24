/// The dive time as the form takes it: whole minutes or `MM:SS`, one to three digits of minutes
/// and two of seconds below 60 (`45`, `67:30`). A bare number is minutes — `130` is 130
/// minutes, never 1:30 — and a mistyped `:75` is refused rather than rolled over.
public enum DiveDuration {
  /// The field's placeholder.
  public static let placeholder = "e.g. 45 or 67:30"

  /// Seconds for a dive time typed in either shape; nil for anything else (`parseFormDuration`
  /// behind the web's pattern).
  public static func seconds(fromForm text: String) -> Int? {
    let parts = text.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
    let minutes = parts[0]
    guard (1...3).contains(minutes.count), minutes.allSatisfy(\.isASCIIDigit),
      let whole = Int(minutes)
    else { return nil }
    guard parts.count == 2 else { return whole * 60 }
    let seconds = parts[1]
    guard seconds.count == 2, seconds.allSatisfy(\.isASCIIDigit), let rest = Int(seconds),
      rest < 60
    else { return nil }
    return whole * 60 + rest
  }

  /// A stored dive time as the form shows it, `M:SS` (`formatDurationForForm`): `45:30`, `1:05`.
  public static func formText(seconds: Int) -> String {
    "\(seconds / 60):" + CalendarDate.pad(seconds % 60, 2)
  }
}

extension Character {
  /// `0` to `9` and nothing else: `isNumber` also takes other scripts' digits and fractions.
  var isASCIIDigit: Bool { ("0"..."9").contains(self) }
}
