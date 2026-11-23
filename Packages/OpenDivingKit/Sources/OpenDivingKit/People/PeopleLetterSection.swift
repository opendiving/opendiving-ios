import Foundation

/// The people filed under one letter on More's *People*, as Contacts files them: by the name's
/// first letter, its case and accents folded, and under `#` where the name opens with no letter.
public struct PeopleLetterSection: Equatable, Sendable, Identifiable {
  public let letter: String
  public let people: [PersonRead]

  public var id: String { letter }

  public init(letter: String, people: [PersonRead]) {
    self.letter = letter
    self.people = people
  }

  /// Where nothing in a name is a letter to file it under.
  public static let other = "#"

  /// The letter `name` is filed under.
  public static func letter(of name: String) -> String {
    guard
      let first = name.trimmingCharacters(in: .whitespacesAndNewlines).first,
      let folded = String(first)
        .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        .uppercased().first,
      folded.isLetter
    else { return other }
    return String(folded)
  }

  /// `people` under their letters in alphabetical order, `#` last, each section keeping the order
  /// they came in.
  public static func sections(_ people: [PersonRead]) -> [PeopleLetterSection] {
    var order: [String] = []
    var filed: [String: [PersonRead]] = [:]
    for person in people {
      let letter = letter(of: person.name)
      if filed[letter] == nil { order.append(letter) }
      filed[letter, default: []].append(person)
    }
    return order.sorted { left, right in
      if left == other || right == other { return right == other && left != other }
      return left < right
    }
    .map { PeopleLetterSection(letter: $0, people: filed[$0] ?? []) }
  }
}
