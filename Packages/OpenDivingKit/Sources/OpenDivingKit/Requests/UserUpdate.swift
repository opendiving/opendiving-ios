/// `PATCH /user`'s body: only what one control changed, since the schema forbids unknown keys
/// and refuses an explicit null. It has no `email`, which changes through its own confirmed
/// flow, and none of the dive form's settings, which the phone reads and never edits.
public struct UserUpdate: Codable, Hashable, Sendable {
  public var name: String?
  public var username: String?
  public var gearServiceEmails: Bool?
  public var renewalReminderEmails: Bool?
  public var yearInReviewEmails: Bool?
  public var units: UnitSystem?

  public init(
    name: String? = nil, username: String? = nil, gearServiceEmails: Bool? = nil,
    renewalReminderEmails: Bool? = nil, yearInReviewEmails: Bool? = nil, units: UnitSystem? = nil
  ) {
    self.name = name
    self.username = username
    self.gearServiceEmails = gearServiceEmails
    self.renewalReminderEmails = renewalReminderEmails
    self.yearInReviewEmails = yearInReviewEmails
    self.units = units
  }
}
