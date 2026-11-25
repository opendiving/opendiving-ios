import OpenDivingKit
import SwiftUI

/// The devices signed in to the account: this phone first, with no control, and each other
/// signed out after a confirmation, or all of them at once.
struct SignedInDevicesSection: View {
  let model: SignedInDevicesModel
  @Environment(Session.self) private var session

  var body: some View {
    if !model.list.isAbsent {
      Section {
        if let lastUpdated = model.list.lastUpdated {
          LastUpdatedLine(date: lastUpdated)
        }
        OptionalListStatus(
          list: model.list, failed: SignedInDevicesModel.loadFailed,
          loading: "Loading signed-in devices…")
        if model.list.value?.isEmpty == true {
          Text(SignedInDevicesModel.empty)
            .foregroundStyle(.secondary)
        }
        ForEach(model.rows) { device in
          row(device)
        }
        if model.hasOthers {
          Button {
            model.confirmingSignOutOthers = true
          } label: {
            HStack {
              Label(row: SignedInDevicesModel.signOutOthersButton, icon: .logOut)
              if model.isSigningOutOthers {
                Spacer()
                BubbleSpinner()
              }
            }
          }
          .accentRow()
          .disabled(model.isBusy)
          .needsServer()
          .confirmationDialog(
            SignedInDevicesModel.signOutOthersButton,
            isPresented: Bindable(model).confirmingSignOutOthers, titleVisibility: .visible
          ) {
            Button(SignedInDevicesModel.signOutOthersConfirm, role: .destructive) {
              Task { await model.confirmSignOutOthers() }
            }
          } message: {
            Text(SignedInDevicesModel.signOutOthersMessage)
          }
        }
      } header: {
        Text("Signed-in devices")
      } footer: {
        VStack(alignment: .leading, spacing: 8) {
          if let failure = model.failure {
            FieldMessage(failure)
          } else if let outcome = model.outcome {
            Text(outcome)
          }
          Text(SignedInDevicesModel.description)
        }
      }
    }
  }

  private func row(_ device: UserSessionRead) -> some View {
    actions(device)
      // The row draws its own insets, so its fill reaches the cell's edges.
      .listRowInsets(EdgeInsets())
  }

  // Nothing on this phone's row: signing it out is what *Sign out* does.
  @ViewBuilder private func actions(_ device: UserSessionRead) -> some View {
    if device.current {
      content(device)
    } else {
      content(device)
        .contextMenu {
          Button(role: .destructive) {
            signOut(device)
          } label: {
            Label(menuItem: SignedInDevicesModel.signOutButton, icon: .logOut)
          }
          .disabled(!canSignOut)
        }
        // The gear service list's swipe rather than the list's own, which draws its button apart
        // from the row.
        .rowSwipeActions(
          trailing: canSignOut
            ? [
              RowSwipeAction(
                title: SignedInDevicesModel.signOutButton, image: Image(.logOut),
                fill: .dangerFill
              ) { signOut(device) }
            ] : []
        )
        .rowConfirmation(
          SignedInDevicesModel.signOutTitle, for: device,
          confirming: Bindable(model).confirmingSignOut
        ) { device in
          Button(SignedInDevicesModel.signOutButton, role: .destructive) {
            Task { await model.confirmSignOut(device) }
          }
        } message: { device in
          Text(SignedInDevicesModel.signOutMessage(device))
        }
    }
  }

  /// Off while another sign-out is under way or the phone has no route to the server.
  private var canSignOut: Bool { !model.isBusy && session.hasRoute }

  private func content(_ device: UserSessionRead) -> some View {
    HStack(spacing: 12) {
      Label {
        VStack(alignment: .leading, spacing: 4) {
          FlowLayout(spacing: 6) {
            Text(SignedInDevicesModel.label(device))
            if device.current {
              BadgeView(SignedInDevicesModel.thisDevice) { EmptyView() }
            }
            if device.idleTimeout == .extended {
              BadgeView(SignedInDevicesModel.staysSignedInLonger, style: .outline) { EmptyView() }
            }
          }
          Text(SignedInDevicesModel.details(device))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      } icon: {
        FirstLineIcon(icon: SignedInDevicesModel.icon(device))
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      if model.signingOut == device.uuid {
        BubbleSpinner()
      }
    }
    // The list's own insets, which the row takes over.
    .padding(.horizontal, 16)
    .padding(.vertical, 15)
    // A swipe slides the row on the cell's own fill.
    .background(Color(.secondarySystemGroupedBackground))
  }

  private func signOut(_ device: UserSessionRead) {
    model.confirmingSignOut = device
  }
}

#Preview {
  @Previewable @State var model = SignedInDevicesModel(session: AuthenticationPreviewData.session)
  List {
    SignedInDevicesSection(model: model)
  }
  .task { await model.list.load() }
  .environment(AuthenticationPreviewData.session)
}
