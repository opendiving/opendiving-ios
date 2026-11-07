import Foundation
import Observation

/// One *Replace with Commons site* on its way, from a match in the propose flow or the site's
/// page. A direct call rather than a queued write, as a withdraw is. What the queue holds naming
/// the site is left alone: the server's alias lands it on the record.
@MainActor
@Observable
public final class CommonsSiteReplacement {
  /// The record the site is being replaced with.
  public private(set) var replacing: UUID?
  /// The sentence of the replace that failed, until the diver has read it.
  public var failure: String?

  @ObservationIgnored private let session: Session

  init(session: Session) {
    self.session = session
  }

  /// Answers the record, once the pickers have dropped the site's row and `read` has run; nil,
  /// with the reason in ``failure``, when the server refused.
  func replace(_ site: UUID, with record: UUID, then read: () async -> Void) async -> DiveSiteRead?
  {
    guard replacing == nil else { return nil }
    replacing = record
    defer { replacing = nil }
    failure = nil
    do {
      let replaced = try await session.requireClient().replaceDiveSite(site, with: record)
      await LookupsModel.refresh(session)
      await read()
      return replaced
    } catch {
      failure = APIError(error).message
      return nil
    }
  }
}
