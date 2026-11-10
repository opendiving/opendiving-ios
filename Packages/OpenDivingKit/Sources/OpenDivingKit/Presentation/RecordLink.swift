import Foundation

/// A record named on another's page, by the name drawn and the uuid its own page opens by: nil
/// for one the server does not have yet, which is drawn as text.
public struct RecordLink: Hashable, Sendable {
  public var title: String
  public var uuid: UUID?

  public init(title: String, uuid: UUID?) {
    self.title = title
    self.uuid = uuid
  }
}
