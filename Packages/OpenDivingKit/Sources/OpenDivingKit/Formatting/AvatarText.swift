/// What a diver's picture falls back to, as the web's `UserAvatar` draws it.
public enum AvatarText {
  /// The first letter of each of the first two words, upper-cased: `Test Diver` is `TD`. Nil
  /// for a name of one word or none, which draws a person instead.
  public static func initials(_ name: String) -> String? {
    let letters = name.split(separator: " ").prefix(2).compactMap(\.first)
    guard letters.count == 2 else { return nil }
    return String(letters).uppercased()
  }
}
