import Foundation

extension PersonRowContent {
  /// The rows for a dive's, a trip's or a course's people, in the record's order, named
  /// through the session's people table. A reference the table cannot resolve — not read
  /// yet, or deleted since — has no row.
  public static func rows(
    _ references: [PersonReference], people: [UUID: PersonRead]
  ) -> [PersonRowContent] {
    references.compactMap { reference in
      guard let person = people[reference.personUuid] else { return nil }
      return PersonRowContent(
        name: person.name,
        username: person.username.flatMap { $0.isEmpty ? nil : $0 },
        role: reference.role.flatMap { $0.isEmpty ? nil : VocabularyLabels.personRole($0) })
    }
  }
}
