/// The words of a record page's list of its dives: the card's title and the sentence under it,
/// and in place of the list, while it holds none, what the empty state says and the label of its
/// button that logs a dive.
public struct RecordDivesContent: Hashable, Sendable {
  public var title: String
  public var description: String
  public var emptyTitle: String
  public var emptyMessage: String
  public var logDiveLabel: String

  public init(
    title: String, description: String, emptyTitle: String, emptyMessage: String,
    logDiveLabel: String
  ) {
    self.title = title
    self.description = description
    self.emptyTitle = emptyTitle
    self.emptyMessage = emptyMessage
    self.logDiveLabel = logDiveLabel
  }

  /// Said in place of the list when a page of it failed, as the web's toast says it.
  public static let failed = "Failed to load dives. Please try again."

  /// A gear item's page.
  public static let gearItem = RecordDivesContent(
    title: "Dives with This Gear", description: "Every dive this item was used on",
    emptyTitle: "Not used on any dive yet",
    emptyMessage: "Add this item to a dive's gear list to see it here.",
    logDiveLabel: "Log a dive")

  /// A course's page.
  public static let course = RecordDivesContent(
    title: "Dives on This Course", description: "All dives logged as part of this course",
    emptyTitle: "No dives logged for this course yet",
    emptyMessage: "Log a dive and assign it to this course to see it here.",
    logDiveLabel: "Log a dive for this course")

  /// A person's page.
  public static let person = RecordDivesContent(
    title: "Dives Together", description: "Every dive that names them",
    emptyTitle: "No dives with them yet",
    emptyMessage: "Add them to a dive's people to see it here.",
    logDiveLabel: "Log a dive")

  /// A species' page, by the name its page heads with.
  public static func species(_ displayName: String) -> RecordDivesContent {
    RecordDivesContent(
      title: "Dives with \(displayName)", description: "Every dive you logged this species on",
      emptyTitle: "No dives with this species yet",
      emptyMessage: "Record it on a dive and it will appear here.",
      logDiveLabel: "Log a dive")
  }
}
