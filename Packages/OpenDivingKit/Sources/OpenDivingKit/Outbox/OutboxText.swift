/// The phone's own sentences about the queue. The server's are shown as it wrote them.
public enum OutboxText {
  /// A success whose body this version could not read: the record exists, the item is done.
  public static let landedUnreadable = "Saved, but this version could not read the server's answer."
  /// A queued change or discard of a draft that another device had finished or discarded.
  public static let draftGone = "The draft was finished or discarded on another device."
  /// A keyed create answered 410 with no sentence of its own.
  public static let createdThenDeleted =
    "It was saved, then deleted on another device before this phone heard back."
  /// An item file this build cannot read.
  public static let unreadableItem = "Saved by another version of the app"
  /// A write naming a record that was discarded before it could be sent.
  public static let namesNothing = "It changes a record that was never saved to the server."

  /// A write moved out of another account's stores that is about that account's record.
  public static func writtenForAnotherAccount(_ label: String?) -> String {
    let whom = label.map { "for \($0)" } ?? "for the account last signed in here"
    return
      "Written \(whom) before your account was known, so it has nothing here to change."
  }
}
