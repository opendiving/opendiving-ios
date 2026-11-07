import Foundation
import Observation

/// The *Import log* screen: `GET /import/{uuid}/notes`.
@MainActor
@Observable
public final class ImportLogModel {
  public enum Phase: Equatable, Sendable {
    case loading
    case loaded(ImportLogContent)
    case failed(APIError)
  }

  public private(set) var phase = Phase.loading

  @ObservationIgnored private let session: Session
  @ObservationIgnored private let uuid: UUID
  @ObservationIgnored private let written: Bool

  /// `written` is whether the import has been applied, which says what a row may open.
  public init(session: Session, uuid: UUID, written: Bool) {
    self.session = session
    self.uuid = uuid
    self.written = written
  }

  /// Loads the log, or retries it.
  public func load() async {
    phase = .loading
    do {
      let log = try await session.requireClient().importNotes(uuid)
      phase = .loaded(ImportLogContent(log, written: written))
    } catch {
      phase = .failed(APIError(error))
    }
  }
}
