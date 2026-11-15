import OpenDivingKit
import SwiftUI

/// The profile's QR button's pane: the diver's invite link as a QR code to show, its reset and
/// removal under it and the share in the top bar, or the way to make one while there is none.
struct InviteQRSheet: View {
  @Environment(Session.self) private var session

  var body: some View {
    InviteQRPane(session: session)
  }
}

private struct InviteQRPane: View {
  @State private var model: InvitationsModel
  @Environment(\.dismiss) private var dismiss

  init(session: Session) {
    _model = State(initialValue: InvitationsModel(session: session))
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 16) {
          content
        }
        .frame(maxWidth: .infinity)
        .padding()
      }
      .navigationTitle("Your invite link")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Close", systemImage: "xmark") { dismiss() }
        }
        if let address = model.linkAddress {
          ToolbarItem(placement: .topBarTrailing) {
            ShareLink(
              item: address, subject: Text(model.shareTitle),
              preview: SharePreview(model.shareTitle)
            ) {
              Label("Share", systemImage: "square.and.arrow.up")
            }
          }
        }
      }
    }
    .task { await model.load() }
    .task { await model.followRoute() }
  }

  @ViewBuilder private var content: some View {
    // Read again each time the pane opens; a read that fails leaves the phone's copy dated.
    if let lastUpdated = model.lastUpdated, !model.list.isAbsent {
      LastUpdatedLine(date: lastUpdated)
    }
    if model.list.isAbsent {
      ContentUnavailableView {
        Label(SettingsSection.invitations.title, systemImage: "envelope.badge.person.crop")
      } description: {
        Text(InvitationsModel.openInstance)
      }
    } else if model.list.value == nil {
      OptionalListStatus(
        list: model.list, failed: InvitationsModel.loadFailed, loading: "Loading your invite link…")
    } else if !model.isLinkRead {
      if let failure = model.linkLoadFailure {
        Text(InvitationsModel.linkLoadFailed + " " + failure)
          .foregroundStyle(.secondary)
        Button("Try again") { Task { await model.loadLink() } }
          .needsServer()
          .accentRow()
      } else {
        HStack {
          BubbleSpinner()
          Text("Loading your invite link…")
        }
        .foregroundStyle(.secondary)
      }
    } else if let address = model.linkAddress {
      InviteQRCode(address: address.absoluteString, label: InvitationsModel.qrLabel)
      Text(InvitationsModel.linkLive)
        .font(.footnote)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
      HStack(spacing: 12) {
        changeButton(.reset)
        changeButton(.remove)
      }
      .controlSize(.large)
      failure
    } else {
      Text(InvitationsModel.linkNone)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
      Button {
        Task { await model.createLink() }
      } label: {
        Label(InvitationsModel.linkCreate, systemImage: "link")
          .frame(maxWidth: .infinity)
      }
      .brandProminentButton()
      .controlSize(.large)
      .disabled(model.isChangingLink)
      .needsServer()
      failure
    }
  }

  @ViewBuilder private var failure: some View {
    if model.isChangingLink {
      BubbleSpinner()
    } else if let failure = model.linkFailure {
      FieldMessage(failure)
    }
  }

  private func changeButton(_ change: InvitationsModel.LinkChange) -> some View {
    let isRemoval = change == .remove
    return Button(role: isRemoval ? .destructive : nil) {
      model.askToConfirm(change)
    } label: {
      Label(
        isRemoval ? InvitationsModel.removeButton : InvitationsModel.resetButton,
        systemImage: isRemoval ? "trash" : "arrow.counterclockwise"
      )
      .frame(maxWidth: .infinity)
    }
    .brandBorderedButton(isRemoval ? .danger : .accentText)
    .disabled(model.isChangingLink)
    .needsServer()
    .confirmsInviteLinkChange(change, model: model)
  }
}

#Preview {
  Color.clear
    .sheet(isPresented: .constant(true)) { InviteQRSheet() }
    .environment(
      Session.stub(
        transport: StubTransport(routes: [
          "GET user/invitations": .json(
            #"{"data":[],"total_count":0,"has_more":false,"page":1,"items_per_page":20}"#),
          "GET user/invite-link": .json(
            #"{"token":"q7Zr2LmWexampleInviteTokenNotReal0123456","#
              + #""created_at":"2026-11-01T10:00:00Z"}"#),
        ])))
}
