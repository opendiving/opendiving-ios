import Foundation
import Observation

/// One applied import, opened from the history: what it wrote, and its *Delete*.
@MainActor
@Observable
public final class ImportDetailModel {
  public enum Phase: Equatable, Sendable {
    case loading
    case loaded(LogbookImportRead)
    case failed(APIError)
  }

  public private(set) var phase = Phase.loading
  /// The numbering sentence, where the import tangled the log's numbering.
  public private(set) var numbering: String?
  public private(set) var isDeleting = false
  /// Why the last delete failed.
  public private(set) var deleteError: String?

  @ObservationIgnored private let session: Session
  @ObservationIgnored private let uuid: UUID

  public init(session: Session, uuid: UUID) {
    self.session = session
    self.uuid = uuid
  }

  /// Loads the import, or retries it.
  public func load() async {
    phase = .loading
    do {
      let client = try session.requireClient()
      let read = try await client.logbookImport(uuid)
      let after = try? await client.diveNumbering()
      numbering = ImportText.numberingSuggestion(
        before: read.numbering, after: after, dives: read.dives)
      phase = .loaded(read)
    } catch {
      phase = .failed(APIError(error))
    }
  }

  /// Takes the import out of the history, its dives staying; true once it has left. A 404 is one
  /// already gone, which is what was asked for.
  public func delete() async -> Bool {
    guard !isDeleting else { return false }
    isDeleting = true
    deleteError = nil
    defer { isDeleting = false }
    do {
      try await session.requireClient().deleteImport(uuid, status: "applied")
    } catch APIError.http(404, _) {
    } catch {
      deleteError = APIError(error).message
      return false
    }
    if let stores = AccountStores.current(session) {
      OutboxHub.hub(for: stores.directory).listsChanged()
    }
    return true
  }
}
