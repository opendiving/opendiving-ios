import Foundation

/// What an import of files did, or would do: the body `POST /import/logbook/preview` and
/// `POST /import/logbook` share. Every `code`, `kind` and outcome is the string the API sent,
/// because it says to treat one a client does not recognise as information.
public struct ImportReport: Codable, Hashable, Sendable {
  /// One per envelope collection, in the envelope's order.
  public let collections: [ImportCollectionReport]
  public let files: ImportFileReport
  /// Every note on no dive's row, grouped.
  public let notes: [ImportNoteGroup]
  /// Groups past the cap that `notes` leaves out.
  public let notesTruncated: Int
  /// One row per file: each part of the request, and each file a zip among them held.
  public let members: [ImportMemberReport]
  /// One row per dive the import creates or touches.
  public let dives: [ImportDiveReport]
}

/// `POST /import/logbook`'s answer: the report of what was written.
public typealias ImportResult = ImportReport

/// `POST /import/logbook/preview`'s answer: the report of what an import would write, and the
/// token that applies it to the same files under the same names.
@dynamicMemberLookup
public struct ImportPreview: Codable, Hashable, Sendable {
  public let report: ImportReport
  /// The first document's own `format` marker.
  public let format: String
  public let version: String
  public let generator: ImportGenerator?
  /// Whether the files carry a full-export archive.
  public let archive: Bool
  public let token: String
  /// Each check-in detail the files carry, the account's value beside the proposal.
  public let checkInDetails: [ImportCheckInDetail]
  /// The archive's portrait beside the account's, when it carries one to offer.
  public let portrait: ImportPortraitOffer?

  public subscript<Value>(dynamicMember keyPath: KeyPath<ImportReport, Value>) -> Value {
    report[keyPath: keyPath]
  }

  enum CodingKeys: String, CodingKey {
    case format, version, generator, archive, token, checkInDetails, portrait
  }

  public init(from decoder: any Decoder) throws {
    report = try ImportReport(from: decoder)
    let c = try decoder.container(keyedBy: CodingKeys.self)
    format = try c.decode(String.self, forKey: .format)
    version = try c.decode(String.self, forKey: .version)
    generator = try c.decodeIfPresent(ImportGenerator.self, forKey: .generator)
    archive = try c.decode(Bool.self, forKey: .archive)
    token = try c.decode(String.self, forKey: .token)
    checkInDetails =
      try c.decodeIfPresent([ImportCheckInDetail].self, forKey: .checkInDetails) ?? []
    portrait = try c.decodeIfPresent(ImportPortraitOffer.self, forKey: .portrait)
  }

  public func encode(to encoder: any Encoder) throws {
    try report.encode(to: encoder)
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(format, forKey: .format)
    try c.encode(version, forKey: .version)
    try c.encodeIfPresent(generator, forKey: .generator)
    try c.encode(archive, forKey: .archive)
    try c.encode(token, forKey: .token)
    try c.encode(checkInDetails, forKey: .checkInDetails)
    try c.encodeIfPresent(portrait, forKey: .portrait)
  }
}

/// What produced an imported document, where it said.
public struct ImportGenerator: Codable, Hashable, Sendable {
  public let name: String?
  public let version: String?
}

/// One envelope collection's records, by what happened to each.
public struct ImportCollectionReport: Codable, Hashable, Sendable {
  public let collection: String
  public let created: Int
  /// Matched a record of the account's; nothing was written.
  public let linked: Int
  /// A record the account deleted, back under its own uuid.
  public let restored: Int
  public let skipped: Int
}

/// The stored files the documents name, and what became of their bytes.
public struct ImportFileReport: Codable, Hashable, Sendable {
  public let referenced: Int
  public let restored: Int
  /// Named, with no bytes in the files: only a full-export archive carries them.
  public let notContained: Int
  public let skipped: Int
}

/// One sentence about one dive of the import.
public struct ImportDiveNote: Codable, Hashable, Sendable {
  public let code: String
  /// `absent`, `inferred`, `resolved`, `dropped` or null.
  public let kind: String?
  public let collection: String?
  public let message: String
}

/// Notes about no one dive, grouped by code, collection and sentence.
public struct ImportNoteGroup: Codable, Hashable, Sendable {
  public let code: String
  public let kind: String?
  public let collection: String?
  public let message: String
  /// How many notes the group holds, which may be more than `wheres` lists.
  public let count: Int
  /// Up to three places in the files, `dives.uddf/dive/0`.
  public let wheres: [String]
}

/// One file of the import: a part of the request, or a file a zip among them held.
public struct ImportMemberReport: Codable, Hashable, Sendable {
  /// The index of the request's `file` part it came from.
  public let part: Int
  /// For a file a zip held, the index in `members` of the zip's own row.
  public let container: Int?
  /// The file's name, or its path inside the zip.
  public let name: String
  public let byteSize: Int
  public let sha256: String
  /// What it was read as; null for a file nothing here reads.
  public let format: String?
  /// On a zip's own row, how many files it opened into.
  public let opened: Int?
  /// Whether the file is kept on the dive it becomes.
  public let kept: Bool
  public let notKept: String?
  /// Why the file was refused, in one sentence; null for one that was read.
  public let refusal: String?
}

/// One dive the import creates or touches.
public struct ImportDiveReport: Codable, Hashable, Sendable {
  /// The dive's identifier once written; null for one the import skips.
  public let uuid: UUID?
  /// `created`, `restored`, `linked`, `updated` or `skipped`.
  public let outcome: String
  public let filesAdded: Int
  public let recordingsAdded: Int
  /// On a skipped dive, why.
  public let reason: String?
  public let startTime: DiveTimestamp?
  /// Seconds.
  public let submergedTime: Int?
  /// Metres.
  public let maxDepth: Double?
  public let device: RecordingDevice?
  /// The indexes in `members` of the files the dive came from.
  public let members: [Int]
  public let notes: [ImportDiveNote]
  /// Notes past the row's cap, which the report's `notes` holds.
  public let notesTruncated: Int
}

/// A check-in detail a logbook carries, the account's value beside the proposal.
public enum ImportCheckInDetail: Hashable, Sendable {
  case email(account: String?, proposed: String)
  case phone(account: String?, proposed: String)
  case dateOfBirth(account: CalendarDate?, proposed: CalendarDate)
  case emergencyContacts(account: [EmergencyContact], proposed: [EmergencyContact])
  case insurancePolicies(account: [InsurancePolicy], proposed: [InsurancePolicy])
  /// A detail this version does not know, kept by name so the rest of the preview reads.
  case other(String)
}

extension ImportCheckInDetail: Codable {
  enum CodingKeys: String, CodingKey { case detail, account, proposed }

  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let detail = try c.decode(String.self, forKey: .detail)
    switch detail {
    case "email":
      self = .email(
        account: try c.decodeIfPresent(String.self, forKey: .account),
        proposed: try c.decode(String.self, forKey: .proposed))
    case "phone":
      self = .phone(
        account: try c.decodeIfPresent(String.self, forKey: .account),
        proposed: try c.decode(String.self, forKey: .proposed))
    case "date_of_birth":
      self = .dateOfBirth(
        account: try c.decodeIfPresent(CalendarDate.self, forKey: .account),
        proposed: try c.decode(CalendarDate.self, forKey: .proposed))
    case "emergency_contacts":
      self = .emergencyContacts(
        account: try c.decode([EmergencyContact].self, forKey: .account),
        proposed: try c.decode([EmergencyContact].self, forKey: .proposed))
    case "insurance_policies":
      self = .insurancePolicies(
        account: try c.decode([InsurancePolicy].self, forKey: .account),
        proposed: try c.decode([InsurancePolicy].self, forKey: .proposed))
    default:
      self = .other(detail)
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .email(let account, let proposed):
      try c.encode("email", forKey: .detail)
      try c.encode(account, forKey: .account)
      try c.encode(proposed, forKey: .proposed)
    case .phone(let account, let proposed):
      try c.encode("phone", forKey: .detail)
      try c.encode(account, forKey: .account)
      try c.encode(proposed, forKey: .proposed)
    case .dateOfBirth(let account, let proposed):
      try c.encode("date_of_birth", forKey: .detail)
      try c.encode(account, forKey: .account)
      try c.encode(proposed, forKey: .proposed)
    case .emergencyContacts(let account, let proposed):
      try c.encode("emergency_contacts", forKey: .detail)
      try c.encode(account, forKey: .account)
      try c.encode(proposed, forKey: .proposed)
    case .insurancePolicies(let account, let proposed):
      try c.encode("insurance_policies", forKey: .detail)
      try c.encode(account, forKey: .account)
      try c.encode(proposed, forKey: .proposed)
    case .other(let detail):
      try c.encode(detail, forKey: .detail)
    }
  }
}

/// The archive's portrait offered beside the account's.
public struct ImportPortraitOffer: Codable, Hashable, Sendable {
  /// The account's portrait as its digest, or null without one; sent back in the choice.
  public let accountSha256: String?
  /// The archive's portrait as a `data:image/webp;base64,` URL.
  public let proposed: String
}
