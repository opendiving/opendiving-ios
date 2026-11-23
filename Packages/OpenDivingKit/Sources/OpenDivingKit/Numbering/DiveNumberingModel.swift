import Foundation
import Observation

/// The numbering card above the dives, the web's: what a renumber would tidy in the log, read
/// from the server. Nil — no card — until it is read, for a tidy log, and wherever the read
/// fails, offline included, since a renumber cannot run without the server either. Once read,
/// it reads again when the account's records change under it, a renumber among them.
@MainActor
@Observable
public final class DiveNumberingModel {
  public private(set) var description: String?

  @ObservationIgnored private let session: Session
  /// The read a change to the account's records started.
  @ObservationIgnored var reloading: Task<Void, Never>?

  public init(session: Session) {
    self.session = session
  }

  public func load() async {
    let summary = try? await session.routedClient().diveNumbering()
    guard !Task.isCancelled else { return }
    description = summary.flatMap(DiveNumberingText.description)
    // After the read, so a card shown over an account that loaded meanwhile hears its renumber.
    if let stores = AccountStores.current(session) {
      OutboxHub.hub(for: stores.directory).observeLists(self)
    }
  }
}

extension DiveNumberingModel: AccountListsObserver {
  func accountListsChanged() {
    reloading = Task { await load() }
  }
}
