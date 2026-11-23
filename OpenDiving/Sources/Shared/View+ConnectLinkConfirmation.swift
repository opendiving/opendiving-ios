import OpenDivingKit
import SwiftUI

extension View {
  /// Asks the diver to confirm `change` to `model`'s connect link while the model waits on it,
  /// then carries it out. Applied to the button that asks, which the dialog points at; the
  /// button asks with ``ConnectLinkModel/askToConfirm(_:)``.
  func confirmsConnectLinkChange(
    _ change: ConnectLinkModel.LinkChange, model: ConnectLinkModel
  ) -> some View {
    confirmationDialog(
      change == .reset ? ConnectLinkModel.resetTitle : ConnectLinkModel.removeTitle,
      isPresented: Binding(
        get: { model.confirmingLink == change },
        set: { if !$0, model.confirmingLink == change { model.confirmingLink = nil } }),
      titleVisibility: .visible, presenting: change
    ) { change in
      Button(
        change == .reset ? ConnectLinkModel.resetButton : ConnectLinkModel.removeButton,
        role: change == .remove ? .destructive : nil
      ) { Task { await model.confirmLinkChange(change) } }
    } message: { change in
      Text(change == .reset ? ConnectLinkModel.resetMessage : ConnectLinkModel.removeMessage)
    }
  }
}
