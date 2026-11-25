import OpenDivingKit
import SwiftUI

extension View {
  /// Asks the diver to confirm `change` to `model`'s connect link while the model waits on it,
  /// then carries it out. Applied to the button that asks, which the dialog points at; the
  /// button asks with ``ConnectLinkModel/askToConfirm(_:)``.
  func confirmsConnectLinkChange(
    _ change: ConnectLinkModel.LinkChange, model: ConnectLinkModel
  ) -> some View {
    modifier(ConnectLinkConfirmation(change: change, model: model))
  }
}

private struct ConnectLinkConfirmation: ViewModifier {
  let change: ConnectLinkModel.LinkChange
  let model: ConnectLinkModel
  @Environment(\.dynamicTypeSize) private var typeSize

  func body(content: Content) -> some View {
    // At the accessibility sizes the popover a dialog is drawn in stays narrow and breaks its
    // words, where an alert spans the screen.
    if typeSize.isAccessibilitySize {
      content.alert(title, isPresented: isPresented, presenting: change) { change in
        actions(change)
        // An alert adds no way out beside a single button without a role, as a dialog does.
        Button("Cancel", role: .cancel) {}
      } message: {
        message($0)
      }
    } else {
      content.confirmationDialog(
        title, isPresented: isPresented, titleVisibility: .visible, presenting: change,
        actions: actions
      ) { message($0) }
    }
  }

  private var title: String {
    change == .reset ? ConnectLinkModel.resetTitle : ConnectLinkModel.removeTitle
  }

  private var isPresented: Binding<Bool> {
    Binding(
      get: { model.confirmingLink == change },
      set: { if !$0, model.confirmingLink == change { model.confirmingLink = nil } })
  }

  @ViewBuilder private func actions(_ change: ConnectLinkModel.LinkChange) -> some View {
    Button(
      change == .reset ? ConnectLinkModel.resetButton : ConnectLinkModel.removeButton,
      role: change == .remove ? .destructive : nil
    ) { Task { await model.confirmLinkChange(change) } }
  }

  private func message(_ change: ConnectLinkModel.LinkChange) -> Text {
    Text(change == .reset ? ConnectLinkModel.resetMessage : ConnectLinkModel.removeMessage)
  }
}
