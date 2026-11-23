import Foundation

/// The letters down a list's index: A to Z whatever the list holds, any other letter it files
/// names under after them, and `#` last. A letter nothing files under is drawn muted, and picking
/// one lands on the nearest letter that has items.
public struct LetterIndexColumn: Equatable, Sendable {
  public static let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".map(String.init)

  /// Every letter the column draws, in its order.
  public let letters: [String]
  private let filed: Set<String>

  /// The column for a list whose sections are filed under `filed`.
  public init(filed: [String]) {
    self.filed = Set(filed)
    let others = self.filed.subtracting(Self.alphabet + [LetterIndex.other]).sorted()
    letters = Self.alphabet + others + [LetterIndex.other]
  }

  /// Whether anything in the list files under `letter`.
  public func hasItems(_ letter: String) -> Bool { filed.contains(letter) }

  /// The letters that have items, in the column's order.
  public var filedLetters: [String] { letters.filter(hasItems) }

  /// The section a pick of `letter` scrolls to: its own, else the next one down the column with
  /// items, else the last one above it.
  public func target(of letter: String) -> String? {
    guard let index = letters.firstIndex(of: letter) else { return nil }
    return letters[index...].first(where: hasItems) ?? letters[..<index].last(where: hasItems)
  }
}
