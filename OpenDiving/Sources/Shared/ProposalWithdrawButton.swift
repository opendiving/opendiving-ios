import OpenDivingKit
import SwiftUI

/// *Withdraw* on a waiting proposal, wherever one is shown.
struct ProposalWithdrawButton: View {
  let proposal: UUID
  let withdrawal: ProposalWithdrawal
  let withdraw: (UUID) async -> Void

  var body: some View {
    Button {
      Task { await withdraw(proposal) }
    } label: {
      if withdrawal.withdrawing == proposal {
        BubbleSpinner()
      } else {
        Text("Withdraw")
      }
    }
    .buttonStyle(.bordered)
    .disabled(withdrawal.withdrawing != nil)
  }
}

extension View {
  /// The sentence of a *Withdraw* that failed. On the screen rather than the notice, which a
  /// refusal's read may take away.
  func proposalWithdrawalAlert(_ withdrawal: ProposalWithdrawal) -> some View {
    alert(
      "The proposal could not be withdrawn",
      isPresented: Binding(
        get: { withdrawal.failure != nil }, set: { if !$0 { withdrawal.failure = nil } })
    ) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(withdrawal.failure ?? "")
    }
  }
}

#Preview {
  ProposalWithdrawButton(
    proposal: UUID(),
    withdrawal: DiveSiteProposalsModel(session: Session.stub(transport: StubTransport(routes: [:])))
      .withdrawal
  ) { _ in }
}
