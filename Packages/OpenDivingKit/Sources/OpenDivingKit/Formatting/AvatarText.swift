/// What a diver's picture falls back to.
public enum AvatarText {
  /// The first letter of each of the first two words, upper-cased: `Test Diver` is `TD`, `Aleksei`
  /// is `A`. Nil for a blank name, which draws a person instead.
  public static func initials(_ name: String) -> String? {
    let letters = name.split(separator: " ").prefix(2).compactMap(\.first)
    guard !letters.isEmpty else { return nil }
    return String(letters).uppercased()
  }
}
