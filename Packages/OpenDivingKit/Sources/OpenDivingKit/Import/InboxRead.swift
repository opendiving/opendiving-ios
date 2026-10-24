import Foundation

/// The inbox's last read: the files it sent, in the order sent, and what the server answered —
/// a preview, or a sentence in place of one. A refusal of the whole request, a 429 and a 5xx
/// are kept the same way, so a read the app started is never retried on the server's answer.
public struct InboxRead: Codable, Hashable, Sendable {
  /// The files sent, in order: a preview's `members[].part` indexes into it, and the apply
  /// sends them again.
  public let files: [UUID]
  public let readAt: Date
  /// The answer, when the server read the files.
  public let preview: ImportPreview?
  /// The log's numbering when the files were read, for the result to say what the import
  /// changed in it; nil when it could not be read.
  public let numbering: DiveNumberingSummary?
  /// The sentence shown in place of the rows when the server read none of it.
  public let refusal: String?
  /// The files changed since the read: the rows give way to *Read the files again*.
  public var stale: Bool

  public init(
    files: [UUID], readAt: Date = Date(), preview: ImportPreview? = nil,
    numbering: DiveNumberingSummary? = nil, refusal: String? = nil, stale: Bool = false
  ) {
    self.files = files
    self.readAt = readAt
    self.preview = preview
    self.numbering = numbering
    self.refusal = refusal
    self.stale = stale
  }

  /// Whether *Import* can be offered over this read.
  public var isImportable: Bool { preview != nil && !stale }
}
