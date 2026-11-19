/// The ``Session/loadAccount()`` that every list of one pull waits on, started by the first list
/// that needs it, so a page's pull reads the account once however many lists it refreshes. A
/// list left out by having no route starts nothing. The load is not cancelled by a list's task
/// ending, since the other lists of the pull are waiting on it.
@MainActor
final class AccountReload {
  private let session: Session
  private var load: Task<Void, any Error>?

  init(session: Session) {
    self.session = session
  }

  func run() async throws {
    let load = self.load ?? Task { try await session.loadAccount() }
    self.load = load
    try await load.value
  }
}
