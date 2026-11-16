import OpenDivingKit
import SwiftUI

/// One invitation sent: who, its state and when, and its revocation while it can still be revoked.
struct InvitationRow: View {
  let model: InvitationsModel
  let invitation: InvitationRead

  var body: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        FlowLayout(spacing: 6) {
          Text(InvitationsModel.title(invitation))
          if let badge = InvitationsModel.badge(invitation) {
            BadgeView(badge, style: invitation.acceptedAt != nil ? .teal : .outline)
          }
        }
        Text(InvitationsModel.details(invitation))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      if model.revoking == invitation.uuid {
        BubbleSpinner()
      } else if InvitationsModel.canRevoke(invitation) {
        Button(role: .destructive) {
          model.confirmingRevoke = invitation
        } label: {
          Image(systemName: "trash").dangerRow()
        }
        .accessibilityLabel("Revoke the invitation to \(invitation.email ?? "")")
        .buttonStyle(.borderless)
        .disabled(model.revoking != nil)
        .needsServer()
        .rowConfirmation(
          InvitationsModel.revokeTitle, for: invitation,
          confirming: Bindable(model).confirmingRevoke
        ) { invitation in
          Button(InvitationsModel.revokeButton, role: .destructive) {
            Task { await model.confirmRevoke(invitation) }
          }
        } message: { invitation in
          Text(InvitationsModel.revokeMessage(invitation))
        }
      }
    }
  }
}

/// *Show older invitations* while the server has more, or the spinner of the read it started.
struct ShowOlderInvitations: View {
  let model: InvitationsModel

  var body: some View {
    if model.list.value?.hasMore == true {
      if model.isLoadingMore {
        BubbleSpinner()
          .frame(maxWidth: .infinity)
      } else {
        Button(InvitationsModel.showOlder) { Task { await model.loadMore() } }
          .needsServer()
          .accentRow()
          .frame(maxWidth: .infinity)
      }
    }
  }
}

#Preview {
  let invitation = InvitationRead(
    uuid: UUID(), email: "sam@example.com",
    createdAt: DiveTimestamp(wireValue: "2026-11-08T09:30:00Z")!, acceptedAt: nil, revokedAt: nil,
    fromInviteLink: false, memberName: nil)
  List {
    InvitationRow(
      model: InvitationsModel(session: .stub(transport: StubTransport(routes: [:]))),
      invitation: invitation)
  }
}
