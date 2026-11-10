import Foundation

/// What a site's proposal notice and a row of *Your Proposals* print.
public enum DiveSiteProposalSummary {
  /// The notice on the site's panel.
  public struct Notice: Hashable, Sendable {
    public var title: String
    public var message: String?
    /// The proposal a *Withdraw* takes back; nil on one that cannot be.
    public var withdrawable: UUID?
  }

  /// One proposal on *Your Proposals*.
  public struct Row: Hashable, Sendable {
    public var siteUUID: UUID
    public var siteName: String
    public var kind: String
    public var date: String
    public var outcome: String
    public var reason: String?
    /// The proposal a *Withdraw* takes back; nil on one that cannot be.
    public var withdrawable: UUID?
  }

  /// How the form for the diver's own site offers the choice between private and public.
  public enum Choice: Hashable, Sendable {
    /// Either can be chosen, and private is where it starts.
    case open
    /// A proposal waits: public, until it is withdrawn or decided.
    case locked
  }

  /// A site of the diver's, as the form holds the choice. Public is not stored: it is what a
  /// waiting proposal reads as, and choosing it is what starts one.
  public enum Visibility: Hashable, Sendable, CaseIterable {
    case `private`, `public`

    public var label: String {
      switch self {
      case .private: "Private"
      case .public: "Public"
      }
    }
  }

  public static let waitingForReview = "Waiting for review"
  public static let visibilityTitle = "Visibility"
  public static let publicExplained =
    "Public proposes this site to OpenDiving Commons: saving shows you what would be published, "
    + "and a reviewer decides."
  public static let lockedExplained =
    "This site is waiting for review. Withdraw, where the site opens on the map, is the way back to private."
  public static let keptTitle = "Not Proposed Yet"
  public static let keptOnThePhone =
    "This site was kept on this phone and stays private. To propose it, choose Public again once "
    + "it has synced."
  public static let replaceTitle = "Replace with Commons site"
  public static let changeExplained =
    "Everyone goes on seeing this site as it is until a reviewer accepts the change. An accepted "
    + "change is public and stays, whatever becomes of your account, and it is published without "
    + "your name."
  public static let changesNothing = "This changes nothing on the Commons site."
  public static let replacedMessage =
    "This site was replaced with a Commons site, so nothing of it can be changed here."

  /// The choice the form offers on `site`, nil on a new site; none where the server takes no
  /// proposals, and none on a Commons record.
  public static func choice(_ site: DiveSiteRead?, isPrimary: Bool) -> Choice? {
    guard isPrimary, site?.isCommons != true else { return nil }
    return site?.isWaitingForReview == true ? .locked : .open
  }

  /// What the diver's own site being in the Commons says on its panel.
  public static func commonsMatch(_ match: DiveSiteCommonsMatch) -> String {
    "This site is in OpenDiving Commons as \(match.name)."
  }

  /// What a replace does, said before it is done.
  public static func replaceMessage(site: String, record: String) -> String {
    "Your dives at \(site) will name \(record) instead, and your notes and tags move to it. "
      + "\(site) is then deleted, with any proposal on it, and a dive draft naming it names "
      + "\(record)."
  }

  /// A waiting proposal's meaning for its kind with *Withdraw*, or a decline with its reason.
  /// A site's read carries no other status, and a later one draws no notice.
  public static func notice(_ proposal: DiveSiteProposalState) -> Notice? {
    switch proposal.status {
    case DiveSiteProposalStatus.waiting:
      return Notice(
        title: waitingForReview, message: waitingMessage(kind: proposal.kind),
        withdrawable: proposal.uuid)
    case DiveSiteProposalStatus.declined:
      return Notice(title: "Declined", message: reason(proposal.reason))
    default:
      return nil
    }
  }

  /// `timeZone` is the day the proposal is printed on; the phone's own unless a test says.
  public static func row(_ proposal: DiveSiteProposalRead, in timeZone: TimeZone = .current) -> Row
  {
    let date = proposal.createdAt.instant.map { DateText.date($0, in: timeZone) }
    return Row(
      siteUUID: proposal.site.uuid, siteName: proposal.site.name,
      kind: kindLabel(proposal.kind),
      date: date ?? DateText.diveDate(proposal.createdAt),
      outcome: outcomeLabel(proposal.status), reason: reason(proposal.reason),
      withdrawable: proposal.status == DiveSiteProposalStatus.waiting ? proposal.uuid : nil)
  }

  private static func waitingMessage(kind: String) -> String {
    kind == DiveSiteProposalKind.change
      ? "Everyone, you included, sees this site as it is until a reviewer accepts your change."
      : "This site stays yours and private until a reviewer accepts it."
  }

  private static func kindLabel(_ kind: String) -> String {
    switch kind {
    case DiveSiteProposalKind.newSite: "New site"
    case DiveSiteProposalKind.change: "Change"
    default: kind
    }
  }

  private static func outcomeLabel(_ status: String) -> String {
    switch status {
    case DiveSiteProposalStatus.waiting: waitingForReview
    case DiveSiteProposalStatus.accepted: "Accepted"
    case DiveSiteProposalStatus.declined: "Declined"
    case DiveSiteProposalStatus.withdrawn: "Withdrawn"
    default: status
    }
  }

  private static func reason(_ reason: String?) -> String? {
    reason?.isEmpty == false ? reason : nil
  }
}
