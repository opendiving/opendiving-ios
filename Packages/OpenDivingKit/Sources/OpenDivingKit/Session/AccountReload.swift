/// The ``Session/loadAccount()`` that every list of one pull waits on, started by the first list
/// that needs it, so a page's pull reads the account once however many lists it refreshes. A
/// list left out by having no route starts nothing. The load is cancelled once every list waiting
/// on it has been.
@MainActor
final class AccountReload {
  private let session: Session
  private var load: Task<Void, any Error>?
  /// The lists that joined the load and have not been cancelled.
  private var waiting = 0

  init(session: Session) {
    self.session = session
  }

  func run() async throws {
    let load = self.load ?? Task { try await session.loadAccount() }
    self.load = load
    waiting += 1
    try await withTaskCancellationHandler {
      try await load.value
    } onCancel: {
      Task { @MainActor in self.leave() }
    }
  }

  private func leave() {
    waiting -= 1
    if waiting == 0 { load?.cancel() }
  }
}
