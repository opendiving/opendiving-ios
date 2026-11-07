import Foundation
import Observation

/// A proposed change to a Commons record: its shared members to correct, the word for the
/// reviewer and the tick. The record stays as it is for everyone until a reviewer accepts, and only
/// what differs is sent.
@MainActor
@Observable
public final class DiveSiteChangeModel: ReloadingListObserver {
  public var values: DiveSiteFormValues
  public var message = ""
  public var ticked = false
  public private(set) var isSending = false
  /// Why nothing was sent, or why the server refused it.
  public private(set) var sendError: String?
  /// Set by the first *Send proposal*, after which the sentences follow the values.
  public private(set) var attempted = false

  @ObservationIgnored private let session: Session
  @ObservationIgnored private let siteUUID: UUID
  @ObservationIgnored private let baseline: DiveSiteFormValues
  @ObservationIgnored var reloading: Task<Void, Never>?

  public init(session: Session, site: DiveSiteRead) {
    self.session = session
    siteUUID = site.uuid
    baseline = DiveSiteFormValues(changing: site)
    values = baseline
  }

  /// The place as plain text, as the change's body spells it: a blank box is none.
  public var locationName: String {
    get { values.location?.name ?? "" }
    set {
      values.location = newValue.trimmedOfWhitespace.isEmpty ? nil : LocationWrite(name: newValue)
    }
  }

  /// The sentence under one field, once a send has been tried.
  public func message(_ field: String) -> String? {
    guard attempted else { return nil }
    return values.changeIssues.first { $0.field == field }?.message
  }

  /// Sends what differs from the record. False, with the reason on screen and the form as it
  /// was, when the form is not valid, nothing differs or the server refused it.
  public func send() async -> Bool {
    guard ticked, !isSending else { return false }
    attempted = true
    sendError = nil
    guard let change = try? values.change(from: baseline) else { return false }
    if change.isEmpty {
      sendError = DiveSiteProposalSummary.changesNothing
      return false
    }
    sendError = CommonsAttestations.refusal(of: message)
    guard sendError == nil else { return false }
    isSending = true
    defer { isSending = false }
    do {
      try await session.requireClient().proposeDiveSite(
        siteUUID,
        DiveSiteProposalCreate(
          attestation: CommonsAttestations.change, message: message, members: change))
    } catch {
      sendError = APIError(error).message
      return false
    }
    await reloadWithEveryList(on: session)
    return true
  }

  /// Nothing here is a list: a call is only telling the lists that are.
  func accountListsChanged() {}
}
