import Observation

/// One settings screen's writes to the account: `PATCH /user` with what a control changed,
/// then `GET /user`, which the session takes as the account. A direct call, online only: with
/// no route it fails at once and saves nothing, and a refusal is the API's sentence, on the
/// screen it came from.
///
/// A write the server took is never shown as failed. Where the read after it fails, ``shown``
/// holds the diver's choice over the account the session still holds, until the session holds
/// another — the next read, on a settings screen's appearance or the app's return.
@MainActor
@Observable
public final class AccountWrite {
  /// While one write is on its way every control waits.
  public private(set) var isSaving = false
  /// Why the last write saved nothing, until the next one starts.
  public private(set) var failure: String?

  @ObservationIgnored private let session: Session
  /// The update being sent, or sent and not yet read back, over the account it was chosen on.
  private var chosen: (update: UserUpdate, over: UserRead?)?

  public init(session: Session) {
    self.session = session
  }

  /// What a control shows: the account as the session holds it, with the write on its way, or
  /// taken and not yet read back, laid over it.
  public var shown: UserUpdate? {
    guard let chosen, chosen.over == session.user else { return nil }
    return chosen.update
  }

  /// Sends `update`. False when nothing was saved, with ``failure`` saying why.
  @discardableResult
  public func save(_ update: UserUpdate) async -> Bool {
    guard !isSaving else { return false }
    failure = nil
    isSaving = true
    defer { isSaving = false }
    chosen = (update, session.user)
    do {
      try await session.routedClient().updateUser(update)
    } catch {
      chosen = nil
      failure = APIError(error).message
      return false
    }
    do {
      try await session.reloadAccount()
      chosen = nil
    } catch {
      // Saved all the same: the choice stays on the control over what the session holds.
    }
    return true
  }
}
