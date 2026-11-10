/// One side of a card in the certification form (`CertificationCardSlot`): what the slot shows,
/// what saving will do to it in words, and its two controls.
public struct CertificationCardSlot: Hashable, Sendable {
  /// What the slot's frame holds.
  public enum Shown: Hashable, Sendable {
    /// Nothing stored, or the stored file struck off: the dashed frame.
    case empty
    /// The stored file, by its metadata.
    case stored(CertificationFileInfo)
    /// The bytes picked, which the stored file gives way to.
    case picked(CertificationCardPick)
  }

  /// The control beside *Upload* or *Replace*.
  public enum Secondary: Hashable, Sendable {
    /// Strikes off the stored file.
    case remove(String)
    /// Drops the picked bytes.
    case discard(String)
    /// Takes back a removal.
    case keep(String)

    public var label: String {
      switch self {
      case .remove(let label), .discard(let label), .keep(let label): label
      }
    }
  }

  public let side: CertificationSide
  /// `Front` or `Back`.
  public let title: String
  public let shown: Shown
  /// `Upload`, or `Replace` over whatever the slot shows, a picked image being as replaceable as
  /// a stored one.
  public let primary: String
  public let secondary: Secondary?
  public let caption: String?

  public init(side: CertificationSide, stored: CertificationFileInfo?, edit: CertificationCardEdit?)
  {
    self.side = side
    title = VocabularyLabels.certificationSide(side.rawValue) ?? side.rawValue
    let name = side.rawValue
    switch edit {
    case .replace(let pick):
      shown = .picked(pick)
      secondary = .discard("Discard the new \(name) image")
      caption =
        "\(stored == nil ? "Added" : "Replaces the stored image") when you save · "
        + DiveDetailText.fileSize(pick.data.count)
    case .remove:
      shown = .empty
      secondary = .keep("Keep the \(name) image")
      caption = "Deleted when you save"
    case .none:
      if let stored {
        shown = .stored(stored)
        secondary = .remove("Remove the \(name) image")
        caption = "\(stored.originalFilename) · \(DiveDetailText.fileSize(stored.byteSize))"
      } else {
        shown = .empty
        secondary = nil
        caption = nil
      }
    }
    primary = shown == .empty ? "Upload" : "Replace"
  }

  /// Both sides, front first, as the form draws them whether or not either is filled.
  public static func slots(
    _ certification: CertificationRead?, edits: CertificationCardEdits
  ) -> [CertificationCardSlot] {
    CertificationSide.allCases.map { side in
      CertificationCardSlot(
        side: side, stored: certification?.file(side: side.rawValue), edit: edits[side])
    }
  }

  /// What the empty frame says, and what a screen reader hears of it.
  public static let notUploaded = "Not uploaded"

  public var emptyLabel: String { "No \(side.rawValue) image uploaded" }
}
