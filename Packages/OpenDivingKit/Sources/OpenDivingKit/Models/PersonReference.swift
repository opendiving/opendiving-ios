import Foundation

/// One person on a dive, a trip or a course: who, and the role they had. The name is looked
/// up in the session's people table.
public struct PersonReference: Codable, Hashable, Sendable {
  public let personUuid: UUID
  /// A role key such as `buddy` or `instructor`, read as the string the API sent; null means
  /// the person was simply there.
  public let role: String?
}
