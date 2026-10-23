/// A position as text: `"27.8506, 34.3136"`, the way a diver pastes one out of a map.
public enum CoordinateFormat {
  /// The pair, or nil when either half is missing — half a position is nowhere.
  public static func format(latitude: Double?, longitude: Double?) -> String? {
    guard let latitude, let longitude else { return nil }
    return decimal(latitude) + ", " + decimal(longitude)
  }

  /// The shortest digits that read back as the value, in fixed notation even below a
  /// millionth, where `String(n)` would switch to `5e-7`.
  static func decimal(_ value: Double) -> String {
    let text = NumberText.plain(value)
    guard text.contains("e") else { return text }
    var fixed = Substring(NumberText.fixed(value, decimals: 20))
    while fixed.last == "0" { fixed = fixed.dropLast() }
    if fixed.last == "." { fixed = fixed.dropLast() }
    return String(fixed)
  }
}
