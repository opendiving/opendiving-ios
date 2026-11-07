import Foundation
import Observation

/// One *Withdraw* on its way, wherever a proposal offers it. A direct call rather than a queued
/// write: the sentence of a refusal belongs on the screen the diver sent it from.
@MainActor
@Observable
public final class ProposalWithdrawal {
  /// The proposal being withdrawn.
  public private(set) var withdrawing: UUID?
  /// The sentence of the withdraw that failed, until the diver has read it.
  public var failure: String?

  @ObservationIgnored private let session: Session

  init(session: Session) {
    self.session = session
  }

  /// `read` runs once the proposal is withdrawn, and after a 409, which says what is shown no
  /// longer stands.
  func withdraw(_ proposal: UUID, then read: () async -> Void) async {
    guard withdrawing == nil else { return }
    withdrawing = proposal
    defer { withdrawing = nil }
    failure = nil
    do {
      try await session.requireClient().withdrawDiveSiteProposal(proposal)
    } catch {
      let error = APIError(error)
      failure = error.message
      guard case .http(status: 409, _) = error else { return }
    }
    await read()
  }
}
