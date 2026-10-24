/// One row of a picker: a record of the server's from a lookup route, or one created on the
/// phone and not yet landed, listed together. The lookups cache stores these and the pickers
/// list them.
public protocol LookupRow: Codable, Hashable, Sendable, RewritesLocalRefs {
  var ref: RecordRef { get }
  /// The record's name.
  var title: String { get }
  /// What tells two of the same name apart, where the row has it.
  var subtitle: String? { get }
}
