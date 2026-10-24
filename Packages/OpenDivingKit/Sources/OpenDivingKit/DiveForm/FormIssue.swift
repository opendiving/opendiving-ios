/// One sentence a form shows under one of its fields — the web's sentence, for the same entry.
public struct FormIssue: Hashable, Sendable {
  /// The field, by the web form's own name: `max_depth`, `submerged_time`, `mixtures`, `parts`.
  public let field: String
  /// The row of a list field — a tank, a sighting, a trip part — when the sentence is a row's.
  public let index: Int?
  /// The member of that row, or of a group such as a contact's address: `end_pressure`.
  public let member: String?
  public let message: String

  public init(field: String, index: Int? = nil, member: String? = nil, message: String) {
    self.field = field
    self.index = index
    self.member = member
    self.message = message
  }
}

/// A form that cannot be saved as it stands, and every sentence saying why: one per field, the
/// first rule that field breaks, as the web shows one message under a field.
public struct FormInvalid: Error, Hashable, Sendable {
  public let issues: [FormIssue]

  public init(issues: [FormIssue]) {
    self.issues = issues
  }

  /// The sentence for one field, or one member of one row.
  public func message(for field: String, index: Int? = nil, member: String? = nil) -> String? {
    issues.first { $0.field == field && $0.index == index && $0.member == member }?.message
  }
}

/// Collects issues, keeping the first sentence for each place.
struct FormIssueList {
  private(set) var issues: [FormIssue] = []

  mutating func add(_ field: String, index: Int? = nil, member: String? = nil, _ message: String?) {
    guard let message else { return }
    guard !issues.contains(where: { $0.field == field && $0.index == index && $0.member == member })
    else { return }
    issues.append(FormIssue(field: field, index: index, member: member, message: message))
  }

  /// Throws the collected issues, if any.
  func check() throws(FormInvalid) {
    if !issues.isEmpty { throw FormInvalid(issues: issues) }
  }
}
