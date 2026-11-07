import Foundation

/// What a site's proposal notice and a row of *Your Proposals* print.
public enum DiveSiteProposalSummary {
  /// The notice on the site's page.
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

  public static let waitingForReview = "Waiting for review"

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
