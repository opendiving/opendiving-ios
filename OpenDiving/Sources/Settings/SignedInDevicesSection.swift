import OpenDivingKit
import SwiftUI

/// The devices signed in to the account: this phone first, with no control, and each other
/// signed out after a confirmation, or all of them at once.
struct SignedInDevicesSection: View {
  let model: SignedInDevicesModel

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

  // Nothing on this phone's row: signing it out is what *Sign out* does.
  @ViewBuilder private func row(_ device: UserSessionRead) -> some View {
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
          .actionEnabled(!model.isBusy)
        }
        // Not the destructive role, whose swipe takes the row away before the dialog asks.
        .swipeActions(edge: .trailing) {
          Button {
            signOut(device)
          } label: {
            Label(menuItem: SignedInDevicesModel.signOutButton, icon: .logOut)
          }
          .tint(.dangerFill)
          .actionEnabled(!model.isBusy)
        }
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
  }

  private func signOut(_ device: UserSessionRead) {
    model.confirmingSignOut = device
  }
}

extension View {
  /// A row action, off while another is under way or the phone has no route to the server.
  fileprivate func actionEnabled(_ isEnabled: Bool) -> some View {
    disabled(!isEnabled).needsServer()
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
