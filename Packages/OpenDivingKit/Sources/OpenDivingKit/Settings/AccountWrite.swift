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
  /// Every write the server took since the session last read the account, over the account
  /// they were taken on.
  private var taken: (update: UserUpdate, over: UserRead?)?
  /// The write on its way.
  private var sending: UserUpdate?

  public init(session: Session) {
    self.session = session
  }

  /// What a control shows: the account as the session holds it, with the writes taken and not
  /// yet read back, and the one on its way, laid over it.
  public var shown: UserUpdate? {
    let kept = taken.flatMap { $0.over == session.user ? $0.update : nil }
    guard let sending else { return kept }
    return kept?.overlaid(with: sending) ?? sending
  }

  /// Sends `update`. False when nothing was saved, with ``failure`` saying why.
  @discardableResult
  public func save(_ update: UserUpdate) async -> Bool {
    guard !isSaving else { return false }
    failure = nil
    isSaving = true
    defer { isSaving = false }
    sending = update
    do {
      try await session.routedClient().updateUser(update)
    } catch {
      sending = nil
      failure = APIError(error).message
      return false
    }
    let over = session.user
    let kept = taken.flatMap { $0.over == over ? $0.update : nil }
    taken = (kept?.overlaid(with: update) ?? update, over)
    sending = nil
    do {
      try await session.reloadAccount()
      taken = nil
    } catch {
      // Saved all the same: the choice stays on the control over what the session holds.
    }
    return true
  }
}

extension UserUpdate {
  /// This update with what `later` sets laid over it.
  fileprivate func overlaid(with later: UserUpdate) -> UserUpdate {
    UserUpdate(
      name: later.name ?? name, username: later.username ?? username,
      gearServiceEmails: later.gearServiceEmails ?? gearServiceEmails,
      renewalReminderEmails: later.renewalReminderEmails ?? renewalReminderEmails,
      yearInReviewEmails: later.yearInReviewEmails ?? yearInReviewEmails,
      units: later.units ?? units)
  }
}
