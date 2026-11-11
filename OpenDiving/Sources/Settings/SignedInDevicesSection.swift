import OpenDivingKit
import SwiftUI

/// The devices signed in to the account: this phone first, with no control, and each other
/// signed out after a confirmation, or all of them at once.
struct SignedInDevicesSection: View {
  let model: SignedInDevicesModel

  var body: some View {
    if !model.list.isAbsent {
      Section {
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
              Label(
                SignedInDevicesModel.signOutOthersButton,
                systemImage: "rectangle.portrait.and.arrow.right")
              if model.isSigningOutOthers {
                Spacer()
                BubbleSpinner()
              }
            }
          }
          .disabled(model.isBusy)
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
    HStack(spacing: 12) {
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
      .frame(maxWidth: .infinity, alignment: .leading)
      // Nothing on this phone's row: signing it out is what *Sign out* does.
      if !device.current {
        if model.signingOut == device.uuid {
          BubbleSpinner()
        } else {
          Button(role: .destructive) {
            model.confirmingSignOut = device
          } label: {
            Image(systemName: "rectangle.portrait.and.arrow.right")
          }
          .tint(Color.danger)
          .accessibilityLabel("Sign out \(SignedInDevicesModel.label(device))")
          .buttonStyle(.borderless)
          .disabled(model.isBusy)
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
    }
  }
}

#Preview {
  @Previewable @State var model = SignedInDevicesModel(session: AuthenticationPreviewData.session)
  List {
    SignedInDevicesSection(model: model)
  }
  .task { await model.list.load() }
}
