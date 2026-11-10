/// What *Data*'s storage prints, as the web's `StorageCard` writes it.
public enum StorageText {
  public static let description =
    "The space your uploaded files take up on this copy of OpenDiving."
  public static let loadFailed = "Couldn't load what your account is storing."
  public static let noLimit = "This copy of OpenDiving sets no storage limit."
  public static let overLimit =
    "Your account is over its storage limit, so an upload that adds to it is refused until"
    + " something is removed."
  public static let compressedNote =
    "Dive-computer files are stored compressed, so they count for less here than the sizes"
    + " listed on your dives."

  /// One kind of upload: its label, its size, and what it is attached to where that is told.
  public struct Kind: Hashable, Sendable {
    public let label: String
    public let size: String
    public let attached: String?

    public init(label: String, size: String, attached: String?) {
      self.label = label
      self.size = size
      self.attached = attached
    }
  }

  /// `12.0 MB used`, or `12.0 MB of 1.0 GB used` against a limit.
  public static func used(_ usage: StorageUsageRead) -> String {
    let used = DiveDetailText.fileSize(usage.usedBytes)
    guard let limit = usage.limitBytes else { return used + " used" }
    return "\(used) of \(DiveDetailText.fileSize(limit)) used"
  }

  /// Whether the account stores more than its limit allows; never without one.
  public static func isOverLimit(_ usage: StorageUsageRead) -> Bool {
    usage.limitBytes.map { usage.usedBytes > $0 } ?? false
  }

  public static func kinds(_ usage: StorageUsageRead) -> [Kind] {
    [
      Kind(
        label: "Dive-computer files", size: DiveDetailText.fileSize(usage.diveFilesBytes),
        attached: attached(usage.diveFilesCount, usage.divesWithFilesCount, "dive")),
      Kind(
        label: "Certification cards",
        size: DiveDetailText.fileSize(usage.certificationFilesBytes),
        attached: attached(
          usage.certificationFilesCount, usage.certificationsWithFilesCount, "certification")),
      Kind(
        label: "Profile picture and portrait", size: DiveDetailText.fileSize(usage.picturesBytes),
        attached: nil),
    ]
  }

  /// `12 files on 9 dives`, or nothing when there are no files.
  private static func attached(_ files: Int, _ owners: Int, _ owner: String) -> String? {
    guard files > 0 else { return nil }
    return DiveDetailText.countNoun(files, "file") + " on "
      + DiveDetailText.countNoun(owners, owner)
  }
}
