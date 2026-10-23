import Foundation

/// `GET /user`: the signed-in account.
public struct UserRead: Codable, Hashable, Sendable {
  public let uuid: UUID
  public let name: String
  public let username: String
  public let email: String
  /// Null means no avatar; otherwise the `?v=` of `GET /user/avatar`.
  public let avatarSha256: String?
  public let avatarOriginalSha256: String?
  public let avatarCrop: PictureCrop?
  /// Null means no portrait, and no request for one; otherwise the `?v=` of
  /// `GET /user/portrait`.
  public let portraitSha256: String?
  public let portraitOriginalSha256: String?
  public let portraitCrop: PictureCrop?
  public let gearServiceEmails: Bool
  public let renewalReminderEmails: Bool
  public let yearInReviewEmails: Bool
  /// A plain string on the wire; anything but `imperial` reads as metric.
  public let units: UnitSystem
  public let diveFormHiddenFields: [String]
  public let diveFormPresetUuid: UUID?
  public let isSuperuser: Bool

  enum CodingKeys: String, CodingKey {
    case uuid, name, username, email, avatarSha256, avatarOriginalSha256, avatarCrop,
      portraitSha256, portraitOriginalSha256, portraitCrop, gearServiceEmails,
      renewalReminderEmails, yearInReviewEmails, units, diveFormHiddenFields,
      diveFormPresetUuid, isSuperuser
  }

  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    uuid = try c.decode(UUID.self, forKey: .uuid)
    name = try c.decode(String.self, forKey: .name)
    username = try c.decode(String.self, forKey: .username)
    email = try c.decode(String.self, forKey: .email)
    avatarSha256 = try c.decodeIfPresent(String.self, forKey: .avatarSha256)
    avatarOriginalSha256 = try c.decodeIfPresent(String.self, forKey: .avatarOriginalSha256)
    avatarCrop = try c.decodeIfPresent(PictureCrop.self, forKey: .avatarCrop)
    portraitSha256 = try c.decodeIfPresent(String.self, forKey: .portraitSha256)
    portraitOriginalSha256 = try c.decodeIfPresent(String.self, forKey: .portraitOriginalSha256)
    portraitCrop = try c.decodeIfPresent(PictureCrop.self, forKey: .portraitCrop)
    gearServiceEmails = try c.decodeIfPresent(Bool.self, forKey: .gearServiceEmails) ?? true
    renewalReminderEmails =
      try c.decodeIfPresent(Bool.self, forKey: .renewalReminderEmails) ?? true
    yearInReviewEmails = try c.decodeIfPresent(Bool.self, forKey: .yearInReviewEmails) ?? true
    // The column has no CHECK and a newer instance may add a system: an unknown value must
    // not fail the whole account, and metric is what the API itself defaults to.
    let units = try c.decodeIfPresent(String.self, forKey: .units)
    self.units = units.flatMap(UnitSystem.init(rawValue:)) ?? .metric
    diveFormHiddenFields =
      try c.decodeIfPresent([String].self, forKey: .diveFormHiddenFields) ?? []
    diveFormPresetUuid = try c.decodeIfPresent(UUID.self, forKey: .diveFormPresetUuid)
    isSuperuser = try c.decodeIfPresent(Bool.self, forKey: .isSuperuser) ?? false
  }
}
