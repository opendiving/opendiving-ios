import Foundation

/// A card image the diver has picked — framed, unless it is a PDF — and not yet queued.
public struct CertificationCardPick: Hashable, Sendable {
  public let data: Data
  /// `image/jpeg`, `image/png`, `image/webp` or `application/pdf`.
  public let contentType: String
  /// What the file is stored, and downloaded, as.
  public let filename: String

  public init(data: Data, contentType: String, filename: String) {
    self.data = data
    self.contentType = contentType
    self.filename = filename
  }

  /// A PDF is kept whole and never drawn.
  public var isPDF: Bool { contentType == CertificationCardEdits.pdfContentType }

  /// A picture framed on the phone, kept as a JPEG: ImageIO writes no WebP.
  public static func framed(_ data: Data, side: CertificationSide) -> CertificationCardPick {
    CertificationCardPick(
      data: data, contentType: "image/jpeg", filename: "card-\(side.rawValue).jpg")
  }
}

/// What saving the form does to one side's stored file.
public enum CertificationCardEdit: Hashable, Sendable {
  case replace(CertificationCardPick)
  case remove
}

/// What saving the form does to each side's stored file, collected and not sent: nothing leaves
/// the phone's form until it is saved, so *Cancel* leaves the stored cards as they were.
public struct CertificationCardEdits: Hashable, Sendable {
  /// The largest card file the API stores (`MAX_CERTIFICATION_FILE_SIZE`).
  public static let maxFileSize = 10 * 1024 * 1024
  public static let pdfContentType = "application/pdf"
  /// The kinds the API stores (`CERTIFICATION_FILE_ACCEPT`).
  public static let contentTypes = ["image/jpeg", "image/png", "image/webp", pdfContentType]

  /// A file over ``maxFileSize``, refused before anything is kept, in the web's words.
  public static let tooLargeTitle = "File too large"
  public static let tooLargeMessage = "Card images must be 10 MB or smaller."
  /// Bytes the phone could not draw, refused before the framing opens.
  public static let unreadable = "That file could not be read as an image."
  /// Said under the two sides before anything is picked.
  public static let hint =
    "PNG, JPEG and WEBP images are shown here. A PDF is stored and can be downloaded, but not "
    + "displayed — if your agency offers both, pick the image."

  private var edits: [CertificationSide: CertificationCardEdit] = [:]

  public init() {}

  public subscript(side: CertificationSide) -> CertificationCardEdit? {
    get { edits[side] }
    set { edits[side] = newValue }
  }

  public var isEmpty: Bool { edits.isEmpty }

  /// Whether a file of `byteCount` bytes is too large to keep.
  public static func isTooLarge(_ byteCount: Int) -> Bool { byteCount > maxFileSize }

  /// Queues each side's change after the certification's own write, front first, so each
  /// waits for the card it belongs to; a side's new image or removal replaces whatever still
  /// waits for it, `reopened` included. A reopened image whose side the diver left untouched
  /// is dropped. Returns the sides the phone could not keep.
  @MainActor
  public func queue(
    of certification: RecordRef, outbox: OutboxModel, reopened: CardReopening? = nil
  ) -> [CertificationSide] {
    if let reopened, edits[reopened.side] == nil { outbox.discard(reopened.item) }
    return CertificationSide.allCases.filter { side in
      do {
        switch edits[side] {
        case .none: return false
        case .remove: try outbox.queue(.deleteCertificationFile(certification, side))
        case .replace(let pick):
          try outbox.queueCardImage(
            pick.data,
            as: CertificationCardUpload(
              side: side, filename: pick.filename, contentType: pick.contentType),
            of: certification)
        }
        return false
      } catch {
        return true
      }
    }
  }

  /// The sentence for a side that was not kept after the card was (the web's toast title).
  public static func notKept(_ side: CertificationSide) -> String {
    "Saved, but the \(side.rawValue) image did not"
  }

  /// A refused card image as the form reopens it: its side holding the bytes it waits with,
  /// to save again, change or drop, and the server's sentence about it. Nil for any other item,
  /// or once its bytes are gone.
  @MainActor
  public static func reopening(_ item: OutboxItem, session: Session) -> CardReopening? {
    guard case .putCertificationFile(_, let upload) = item.operation,
      let stores = AccountStores.current(session),
      let data = try? Data(contentsOf: stores.outbox.cardFile(for: item.id))
    else { return nil }
    return CardReopening(
      item: item.id, side: upload.side,
      pick: CertificationCardPick(
        data: data, contentType: upload.contentType, filename: upload.filename),
      failure: item.failure?.message ?? item.lastAnswer?.sentence)
  }

  /// A refused card image the form opened over.
  public struct CardReopening: Hashable, Sendable {
    public let item: UUID
    public let side: CertificationSide
    public let pick: CertificationCardPick
    public let failure: String?
  }

  /// The edits a form opens with: the reopened side's bytes, or nothing.
  public init(reopening: CardReopening?) {
    if let reopening { edits[reopening.side] = .replace(reopening.pick) }
  }
}
