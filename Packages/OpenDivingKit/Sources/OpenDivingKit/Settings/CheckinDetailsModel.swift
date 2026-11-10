import Foundation
import Observation

/// *Check-in*: the details a dive shop's desk asks for, in three groups that each save alone.
///
/// Nothing is offered for saving until `GET /user/checkin-details` has answered: a group seeded
/// from a read that never arrived would send itself empty and clear what is stored. Every call
/// is direct and online only, through ``Session/routedClient()``; a refusal is the API's
/// sentence under the group it came from, and what was typed stays. The portrait rides *About
/// You*'s save, sent after its fields.
@MainActor
@Observable
public final class CheckinDetailsModel {
  /// The details as the server last answered them; nil until the first read lands.
  public private(set) var details: CheckinDetailsRead?
  public private(set) var isLoading = false
  /// Why the read failed, until the next one starts.
  public private(set) var loadFailure: String?
  /// What the screen edits. Each save puts its own group back as the server answered it.
  public var draft = CheckinDetailsDraft()
  /// The groups whose save is on its way.
  public private(set) var saving: Set<CheckinGroup> = []
  /// Why a group's last save stored nothing, until its next one starts.
  public private(set) var failures: [CheckinGroup: String] = [:]
  /// What a group's last save found it could not send, by box.
  public private(set) var problems: [CheckinField: String] = [:]
  /// The groups whose last save landed.
  public private(set) var saved: Set<CheckinGroup> = []
  /// *About You*'s 7:9 portrait.
  public let portrait: PictureFieldModel

  @ObservationIgnored private let session: Session

  public init(session: Session) {
    self.session = session
    portrait = PictureFieldModel(kind: .portrait, session: session)
  }

  /// The address the diver signs in with, which the email box offers to fill itself with.
  public var signInEmail: String? { session.user?.email }

  /// Reads the details, unless they have already been read.
  public func load() async {
    guard details == nil, !isLoading else { return }
    isLoading = true
    loadFailure = nil
    defer { isLoading = false }
    do {
      let answer = try await session.routedClient().checkinDetails()
      details = answer
      draft = CheckinDetailsDraft(answer)
    } catch {
      loadFailure = APIError(error).message
    }
  }

  /// Reads the details each time a route appears while they are still unread, until the calling
  /// task is cancelled.
  public func followRoute() async {
    await session.connectivity.eachRouteAppearance { await load() }
  }

  public func isSaving(_ group: CheckinGroup) -> Bool { saving.contains(group) }

  /// Saves `group` alone, and for *About You* the portrait after it. False when nothing was
  /// stored, with ``problems`` or ``failures`` saying why; a portrait the server refused after
  /// the fields saved is a failure of the group's while the save is still true.
  @discardableResult
  public func save(_ group: CheckinGroup, today: CalendarDate = .today()) async -> Bool {
    guard details != nil, !saving.contains(group) else { return false }
    failures[group] = nil
    saved.remove(group)
    let found = draft.problems(for: group, today: today)
    problems = problems.filter { $0.key.group != group }.merging(found) { $1 }
    guard found.isEmpty else { return false }
    guard case .signedIn(let origin) = session.state else {
      failures[group] = APIError.signedOut.message
      return false
    }
    saving.insert(group)
    defer { saving.remove(group) }
    let answer: CheckinDetailsRead
    do {
      answer = try await session.routedClient().updateCheckinDetails(draft.update(for: group))
    } catch {
      failures[group] = APIError(error).message
      return false
    }
    details = answer
    draft.reset(group, to: answer)
    // The kept sheet is the server's, not the account's, so it is written only while the
    // account that saved is still the one signed in there. A sheet that could not be rewritten
    // shows the old details until its next refresh, which is no worse than before the save; the
    // save itself landed.
    let sheets = CheckinSheetStore(store: session.store, origin: origin)
    if session.state == .signedIn(origin) {
      try? sheets.replaceDetails(with: answer)
    }
    if group == .about, portrait.edit != nil {
      if let failure = await portrait.send() {
        failures[group] = portrait.kind.notSaved(failure, afterFields: true)
        return true
      }
      if session.state == .signedIn(origin), let client = try? session.routedClient() {
        try? await sheets.replacePortrait(version: session.user?.portraitSha256, using: client)
      }
    }
    saved.insert(group)
    return true
  }

  /// Whether another row can be added to the list `group` holds.
  public func canAddRow(to group: CheckinGroup) -> Bool {
    switch group {
    case .about: false
    case .insurance: draft.insurancePolicies.count < CheckinDetailsDraft.maxInsurancePolicies
    case .emergency: draft.emergencyContacts.count < CheckinDetailsDraft.maxEmergencyContacts
    }
  }
}
