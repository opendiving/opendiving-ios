import Foundation

/// An import the server holds: its review while `pending`, and what became of it once `applied`.
/// One shape for both, the answer of `POST /imports`, `GET /imports/pending`, `GET /import/{uuid}`
/// and `POST /import/{uuid}/apply`. Every `code`, `kind`, `status` and outcome is the string the
/// API sent, because it says to treat one a client does not recognise as information.
public struct LogbookImportRead: Codable, Hashable, Sendable, Identifiable {
  public let uuid: UUID
  /// `pending` or `applied`.
  public let status: String
  public let createdAt: DiveTimestamp
  /// Null while pending.
  public let appliedAt: DiveTimestamp?
  /// When the server deletes it, or null where the instance sets no limit.
  public let expiresAt: DiveTimestamp?
  /// Whether the files carry a full-export archive.
  public let archive: Bool
  /// One row per file: each part of the upload, and each file a zip among them held.
  public let members: [ImportMemberReport]
  /// One per envelope collection, in the envelope's order.
  public let collections: [ImportCollectionReport]
  public let files: ImportFileReport
  /// One row per dive the files hold, newest first; on an applied import, rows the review did
  /// not show follow the ones it did.
  public let dives: [LogbookImportDive]
  /// Each check-in detail the files carry, the account's value beside the proposal; pending only.
  public let checkInDetails: [ImportCheckInDetail]
  /// The archive's portrait beside the account's, when it carries one to offer; pending only.
  public let portrait: ImportPortraitOffer?
  /// The log's numbering when the files were uploaded.
  public let numbering: DiveNumberingSummary

  public var id: UUID { uuid }
  public var isApplied: Bool { status == "applied" }
}

/// One dive the import's files hold, and what the import does to it.
public struct LogbookImportDive: Codable, Hashable, Sendable {
  /// The dive's identifier, a new dive's as it will be written. Null for a dive the upload
  /// skipped, and for one the apply skipped that the review did not show.
  public let uuid: UUID?
  /// `new`, `modified`, `unchanged` or `skipped`.
  public let outcome: String
  /// The dive as the import leaves it, on a `new` or `modified` row and on a row the apply
  /// skipped. The identifiers of a recording, file or profile nested in it can name nothing
  /// once applied, so nothing downloads or reads by them.
  public let dive: DiveReadWithMixtures?
  /// What changes on a `modified` dive; empty on any other.
  public let changes: [LogbookImportChange]
  public let startTime: DiveTimestamp?
  public let device: RecordingDevice?
  /// The indexes in `members` of the files the dive came from.
  public let members: [Int]
  /// On a skipped dive, why.
  public let reason: String?
}

/// One member of a dive the import changes, what it was and what it becomes.
public struct LogbookImportChange: Codable, Hashable, Sendable {
  /// A path in the dive's read shape: `recordings/0/device/name`, `mixtures/1/start_pressure`,
  /// `recordings/1`, `recordings/0/files/1`.
  public let member: String
  /// Null where the member did not exist.
  public let before: ImportChangeValue
  /// Null where it no longer does.
  public let after: ImportChangeValue
}

/// A member's value as a dive read gives it, which may be any JSON at all. An object keeps the
/// API's keys as they were sent.
public enum ImportChangeValue: Codable, Hashable, Sendable {
  case null
  case bool(Bool)
  case number(Double)
  case string(String)
  case array([ImportChangeValue])
  case object([String: ImportChangeValue])

  public init(from decoder: any Decoder) throws {
    let c = try decoder.singleValueContainer()
    if c.decodeNil() {
      self = .null
    } else if let value = try? c.decode(Bool.self) {
      self = .bool(value)
    } else if let value = try? c.decode(Double.self) {
      self = .number(value)
    } else if let value = try? c.decode(String.self) {
      self = .string(value)
    } else if let value = try? c.decode([ImportChangeValue].self) {
      self = .array(value)
    } else {
      self = .object(try c.decode([String: ImportChangeValue].self))
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var c = encoder.singleValueContainer()
    switch self {
    case .null: try c.encodeNil()
    case .bool(let value): try c.encode(value)
    case .number(let value): try c.encode(value)
    case .string(let value): try c.encode(value)
    case .array(let value): try c.encode(value)
    case .object(let value): try c.encode(value)
    }
  }
}

/// One applied import, as `GET /imports` lists it.
public struct LogbookImportSummary: Codable, Hashable, Sendable, Identifiable {
  public let uuid: UUID
  public let createdAt: DiveTimestamp
  public let appliedAt: DiveTimestamp
  /// How many of its dive rows came to each outcome; an outcome none did is left out.
  public let counts: [String: Int]

  public var id: UUID { uuid }
}

/// `GET /import/{uuid}/notes`: each dive's notes, and what is about no dive.
public struct LogbookImportNotes: Codable, Hashable, Sendable {
  /// One per dive row, in the review's order.
  public let dives: [LogbookImportDiveNotes]
  /// Every note on no dive's row, grouped.
  public let notes: [ImportNoteGroup]
  /// Groups past the cap that `notes` leaves out.
  public let notesTruncated: Int
}

/// Everything an import has to say about one dive.
public struct LogbookImportDiveNotes: Codable, Hashable, Sendable {
  public let uuid: UUID?
  public let startTime: DiveTimestamp?
  public let device: RecordingDevice?
  public let outcome: String
  /// On a skipped dive, why.
  public let reason: String?
  public let notes: [ImportDiveNote]
  /// Notes past the row's cap, which the log's `notes` holds.
  public let notesTruncated: Int
}

/// One envelope collection's records, by what happened to each.
public struct ImportCollectionReport: Codable, Hashable, Sendable {
  public let collection: String
  public let created: Int
  /// Matched a record of the account's; nothing was written.
  public let linked: Int
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

/// One file of the import: a part of the upload, or a file a zip among them held.
public struct ImportMemberReport: Codable, Hashable, Sendable {
  /// The index of the upload's `file` part it came from.
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

/// A check-in detail a logbook carries, the account's value beside the proposal.
public enum ImportCheckInDetail: Hashable, Sendable {
  case email(account: String?, proposed: String)
  case phone(account: String?, proposed: String)
  case dateOfBirth(account: CalendarDate?, proposed: CalendarDate)
  case emergencyContacts(account: [EmergencyContact], proposed: [EmergencyContact])
  case insurancePolicies(account: [InsurancePolicy], proposed: [InsurancePolicy])
  /// A detail this version does not know, kept by name so the rest of the import reads.
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
