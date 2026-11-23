import Foundation

/// A list's items under the letter their names start with, in the list's order.
public struct LetterSection<Item>: Identifiable {
  public let letter: String
  public let items: [Item]

  public var id: String { letter }
}

extension LetterSection: Sendable where Item: Sendable {}

/// A list grouped by its names' first letters and the index at its edge that jumps between them,
/// as a phone's contacts.
public enum LetterIndex {
  /// Where a name that starts with no letter goes.
  public static let other = "#"

  /// The letter a name files under: its first letter without its accent, in capitals, or
  /// `other`.
  public static func letter(of name: String) -> String {
    guard let first = name.trimmingCharacters(in: .whitespacesAndNewlines).first, first.isLetter
    else { return other }
    let folded = String(first).folding(options: .diacriticInsensitive, locale: nil).uppercased()
    return folded.first.map(String.init) ?? other
  }

  /// The items under their letters, the letters in the order the list first reaches them and
  /// `other` last. An already sorted list keeps each item in its place; an item the sort put away
  /// from its letter joins it there.
  public static func sections<Item>(_ items: [Item], name: (Item) -> String)
    -> [LetterSection<Item>]
  {
    var letters: [String] = []
    var grouped: [String: [Item]] = [:]
    for item in items {
      let letter = letter(of: name(item))
      if grouped[letter] == nil { letters.append(letter) }
      grouped[letter, default: []].append(item)
    }
    if let index = letters.firstIndex(of: other) { letters.append(letters.remove(at: index)) }
    return letters.map { LetterSection(letter: $0, items: grouped[$0] ?? []) }
  }

  /// The letter a touch at `offset` down an index of `height` points falls on, the letters
  /// sharing it evenly; one beyond either end takes the nearest letter.
  public static func letter(at offset: Double, height: Double, letters: [String]) -> String? {
    guard !letters.isEmpty, height > 0 else { return letters.first }
    let position = Int((offset / height * Double(letters.count)).rounded(.down))
    return letters[min(max(position, 0), letters.count - 1)]
  }
}
