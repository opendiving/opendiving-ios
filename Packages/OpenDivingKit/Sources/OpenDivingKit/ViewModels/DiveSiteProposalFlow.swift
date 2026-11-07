import Foundation
import Observation

/// The propose flow for the diver's own site, as the server holds it: whether it is in the Commons
/// already, then what would be published, the word for the reviewer and the tick. Proposing,
/// replacing and the matches are direct calls: a refusal belongs on the screen it was sent from.
@MainActor
@Observable
public final class DiveSiteProposalFlow: ReloadingListObserver {
  public enum Step: Hashable, Sendable {
    case loading, matches, review
  }

  public private(set) var site: DiveSiteRead
  public private(set) var step: Step = .loading
  public private(set) var matches: [DiveSiteCommonsMatchRead] = []
  /// Why the matches could not be had.
  public private(set) var loadError: String?
  /// The review step has a step to go back to, which a skipped one does not.
  public private(set) var canGoBack = false
  public var message = ""
  public var ticked = false
  public private(set) var isSending = false
  /// Why the proposal was not taken.
  public private(set) var sendError: String?
  /// A match's *Replace with Commons site*.
  public let replacement: CommonsSiteReplacement

  @ObservationIgnored private let session: Session
  @ObservationIgnored var reloading: Task<Void, Never>?

  public init(session: Session, site: DiveSiteRead) {
    self.session = session
    self.site = site
    replacement = CommonsSiteReplacement(session: session)
  }

  public var hasPin: Bool { site.latitude != nil && site.longitude != nil }

  /// The matches step says what is missing and offers *Edit*, the review step being out of reach.
  public var needsPin: Bool { loadError == nil && !hasPin }

  public var hasIdentityMatch: Bool {
    matches.contains { $0.rule == DiveSiteCommonsMatchRule.identity }
  }

  /// *Continue as a new site* is there once the matches have said nothing against it.
  public var canContinue: Bool { loadError == nil && hasPin && !hasIdentityMatch }

  /// Asks for the matches. An empty answer has nothing to show, so the flow goes on to the review;
  /// a site with no pin stays on the step, which says what it needs.
  public func load() async {
    step = .loading
    loadError = nil
    canGoBack = false
    do {
      matches = try await session.requireClient().diveSiteCommonsMatches(site.uuid)
    } catch {
      matches = []
      loadError = APIError(error).message
      step = .matches
      return
    }
    step = matches.isEmpty && hasPin ? .review : .matches
  }

  /// The form *Edit* opened has saved: a changed pin or a new registry entry can change the
  /// answer, so the flow starts over, and the tick was on what the site said before.
  public func restart(with site: DiveSiteRead) async {
    self.site = site
    ticked = false
    sendError = nil
    await load()
  }

  public func continueAsNewSite() {
    canGoBack = true
    step = .review
  }

  public func back() {
    sendError = nil
    step = .matches
  }

  /// Sends the site as it stands. False, with the reason on screen and the step as it was, when
  /// the server refused it.
  public func send() async -> Bool {
    guard ticked, !isSending else { return false }
    sendError = CommonsAttestations.refusal(of: message)
    guard sendError == nil else { return false }
    isSending = true
    defer { isSending = false }
    do {
      try await session.requireClient().proposeDiveSite(
        site.uuid,
        DiveSiteProposalCreate(attestation: CommonsAttestations.newSite, message: message))
    } catch {
      sendError = APIError(error).message
      return false
    }
    await reloadWithEveryList(on: session)
    return true
  }

  /// The record, once the site has become it; nil with the reason on ``replacement``.
  public func replace(with record: UUID) async -> DiveSiteRead? {
    await replacement.replace(site.uuid, with: record) { await reloadWithEveryList(on: session) }
  }

  /// Nothing here is a list: a call is only telling the lists that are.
  func accountListsChanged() {}
}
