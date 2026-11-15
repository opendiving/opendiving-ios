import OpenDivingKit
import SwiftUI

extension View {
  /// Asks the diver to confirm `change` to `model`'s invite link while the model waits on it,
  /// then carries it out.
  func confirmsInviteLinkChange(
    _ change: InvitationsModel.LinkChange, model: InvitationsModel
  ) -> some View {
    confirmationDialog(
      change == .reset ? InvitationsModel.resetTitle : InvitationsModel.removeTitle,
      isPresented: Binding(
        get: { model.confirmingLink == change },
        set: { if !$0, model.confirmingLink == change { model.confirmingLink = nil } }),
      titleVisibility: .visible, presenting: change
    ) { change in
      Button(
        change == .reset ? InvitationsModel.resetButton : InvitationsModel.removeButton,
        role: change == .remove ? .destructive : nil
      ) { Task { await model.confirmLinkChange(change) } }
    } message: { change in
      Text(change == .reset ? InvitationsModel.resetMessage : InvitationsModel.removeMessage)
    }
  }
}
