import Foundation

/// One person on a dive, a trip or a course: who, and the role they had. The name is looked
/// up in the session's people table. Read and written in the same shape, so a form sends back
/// what it was given, a person the phone created among them.
public struct PersonReference: Codable, Hashable, Sendable {
  public var person: RecordRef
  /// A role key such as `buddy` or `instructor`, read as the string the API sent; null means
  /// the person was simply there.
  public var role: String?

  enum CodingKeys: String, CodingKey {
    case person = "personUuid"
    case role
  }

  public init(person: RecordRef, role: String? = nil) {
    self.person = person
    self.role = role
  }
}

extension Array where Element == PersonReference {
  /// A dropped person leaves the list, role and all.
  mutating func rewritePeople(_ rewrite: (RecordRef) -> RecordRef?) {
    self = compactMap { reference in
      rewrite(reference.person).map { PersonReference(person: $0, role: reference.role) }
    }
  }
}
