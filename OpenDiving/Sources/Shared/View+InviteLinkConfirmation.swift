import OpenDivingKit
import SwiftUI

extension View {
  /// Asks the diver to confirm the change to `model`'s invite link that the model waits on,
  /// then carries it out. One dialog for both changes, applied once over the buttons that ask:
  /// a dialog of each button's own, asked for while the other's is closing, is never shown and
  /// leaves its change waiting, so its button does nothing until the other is tapped.
  func confirmsInviteLinkChanges(_ model: InvitationsModel) -> some View {
    modifier(InviteLinkConfirmation(model: model))
  }
}

private struct InviteLinkConfirmation: ViewModifier {
  let model: InvitationsModel

  /// The change last asked about, which keeps the dialog's title while it closes.
  @State private var asked = InvitationsModel.LinkChange.reset

  func body(content: Content) -> some View {
    content
      .onChange(of: model.confirmingLink) { _, change in
        if let change { asked = change }
      }
      .confirmationDialog(
        Self.title(model.confirmingLink ?? asked),
        isPresented: Binding(
          get: { model.confirmingLink != nil },
          set: { if !$0 { model.confirmingLink = nil } }),
        titleVisibility: .visible, presenting: model.confirmingLink
      ) { change in
        Button(
          change == .reset ? InvitationsModel.resetButton : InvitationsModel.removeButton,
          role: change == .remove ? .destructive : nil
        ) { Task { await model.confirmLinkChange(change) } }
      } message: { change in
        Text(change == .reset ? InvitationsModel.resetMessage : InvitationsModel.removeMessage)
      }
  }

  private static func title(_ change: InvitationsModel.LinkChange) -> String {
    change == .reset ? InvitationsModel.resetTitle : InvitationsModel.removeTitle
  }
}
