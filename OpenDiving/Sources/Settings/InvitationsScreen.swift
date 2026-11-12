import OpenDivingKit
import SwiftUI

/// *Settings* → *Invitations*: the diver's invite link over the form that sends an invitation
/// and the invitations sent, the whole section left out where anyone may join the server.
struct InvitationsScreen: View {
  @Environment(Session.self) private var session

  var body: some View {
    InvitationsList(session: session)
      .navigationTitle(SettingsSection.invitations.title)
      .followsAccount(session)
  }
}

private struct InvitationsList: View {
  @State private var model: InvitationsModel

  init(session: Session) {
    _model = State(initialValue: InvitationsModel(session: session))
  }

  var body: some View {
    Group {
      if model.list.isAbsent {
        ContentUnavailableView {
          Label(SettingsSection.invitations.title, systemImage: "envelope.badge.person.crop")
        } description: {
          Text(InvitationsModel.openInstance)
        }
      } else {
        List {
          if model.list.value != nil {
            InviteLinkSection(model: model)
          }
          SendInvitationSection(model: model)
          SentInvitationsSection(model: model)
        }
      }
    }
    .task { await model.load() }
    .task { await model.followRoute() }
    .bubbleRefreshable { await model.load() }
  }
}

/// The diver's own link: offered while there is none, then its QR code, its address, a share and
/// its reset and removal.
private struct InviteLinkSection: View {
  let model: InvitationsModel

  var body: some View {
    Section {
      if !model.isLinkRead {
        if let failure = model.linkLoadFailure {
          VStack(alignment: .leading, spacing: 8) {
            Text(InvitationsModel.linkLoadFailed + " " + failure)
              .foregroundStyle(.secondary)
            Button("Try again") { Task { await model.loadLink() } }
              .buttonStyle(.borderless)
          }
        } else {
          HStack {
            BubbleSpinner()
            Text("Loading your invite link…")
          }
          .foregroundStyle(.secondary)
        }
      } else if let address = model.linkAddress {
        InviteQRCode(address: address.absoluteString, label: InvitationsModel.qrLabel)
          .frame(maxWidth: .infinity)
          .listRowBackground(Color.clear)
        Text(InvitationsModel.linkLive)
          .font(.footnote)
          .foregroundStyle(.secondary)
        CopyField(
          value: address.absoluteString, label: InvitationsModel.linkAddressLabel,
          copied: InvitationsModel.linkCopied
        )
        .buttonStyle(.borderless)
        ShareLink(
          item: address, subject: Text(model.shareTitle),
          preview: SharePreview(model.shareTitle)
        ) {
          Label("Share", systemImage: "square.and.arrow.up")
        }
        changeButton(InvitationsModel.resetButton, "arrow.counterclockwise", .reset)
        changeButton(InvitationsModel.removeButton, "trash", .remove)
      } else {
        Text(InvitationsModel.linkNone)
          .font(.footnote)
          .foregroundStyle(.secondary)
        HStack {
          Button {
            Task { await model.createLink() }
          } label: {
            Label(InvitationsModel.linkCreate, systemImage: "link")
          }
          .disabled(model.isChangingLink)
          if model.isChangingLink {
            Spacer()
            BubbleSpinner()
          }
        }
      }
    } header: {
      Text("Your invite link")
    } footer: {
      if let failure = model.linkFailure {
        FieldMessage(failure)
      }
    }
  }

  private func changeButton(
    _ title: String, _ icon: String, _ change: InvitationsModel.LinkChange
  ) -> some View {
    let role: ButtonRole? = change == .remove ? .destructive : nil
    return Button(role: role) {
      model.confirmingLink = change
    } label: {
      Label(title, systemImage: icon)
    }
    .disabled(model.isChangingLink)
    .confirmationDialog(
      change == .reset ? InvitationsModel.resetTitle : InvitationsModel.removeTitle,
      isPresented: Binding(
        get: { model.confirmingLink == change },
        set: { if !$0, model.confirmingLink == change { model.confirmingLink = nil } }),
      titleVisibility: .visible, presenting: change
    ) { change in
      Button(title, role: role) { Task { await model.confirmLinkChange(change) } }
    } message: { change in
      Text(change == .reset ? InvitationsModel.resetMessage : InvitationsModel.removeMessage)
    }
  }
}

/// The address to invite and its *Send invitation*.
private struct SendInvitationSection: View {
  @Bindable var model: InvitationsModel

  var body: some View {
    Section {
      VStack(alignment: .leading, spacing: 6) {
        TextField("Email", text: $model.email, prompt: Text(InvitationsModel.emailPlaceholder))
          .keyboardType(.emailAddress)
          .textContentType(.emailAddress)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .submitLabel(.send)
          .onSubmit { Task { await model.send() } }
        if let error = model.emailError {
          FieldMessage(error)
        }
      }
      .disabled(model.isSending)
      HStack {
        Button {
          Task { await model.send() }
        } label: {
          Label(InvitationsModel.sendButton, systemImage: "paperplane")
        }
        .disabled(model.isSending)
        if model.isSending {
          Spacer()
          BubbleSpinner()
        }
      }
    } header: {
      Text("Invite someone")
    } footer: {
      VStack(alignment: .leading, spacing: 8) {
        if let failure = model.sendFailure {
          FieldMessage(failure)
        } else if let note = model.sentNote {
          FieldMessage(note, isNote: true)
        }
        Text(InvitationsModel.description)
      }
    }
  }
}

/// The invitations sent, newest first, paged by *Show older invitations*.
private struct SentInvitationsSection: View {
  let model: InvitationsModel

  var body: some View {
    Section {
      OptionalListStatus(
        list: model.list, failed: InvitationsModel.loadFailed, loading: "Loading invitations…")
      if model.list.value?.invitations.isEmpty == true {
        Text(InvitationsModel.empty)
          .foregroundStyle(.secondary)
      }
      ForEach(model.list.value?.invitations ?? []) { invitation in
        row(invitation)
      }
      if model.list.value?.hasMore == true {
        if model.isLoadingMore {
          BubbleSpinner()
            .frame(maxWidth: .infinity)
        } else {
          Button(InvitationsModel.showOlder) { Task { await model.loadMore() } }
            .frame(maxWidth: .infinity)
        }
      }
    } header: {
      Text("Invitations")
    } footer: {
      if let failure = model.revokeFailure ?? model.loadMoreFailure {
        FieldMessage(failure)
      }
    }
  }

  private func row(_ invitation: InvitationRead) -> some View {
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
          Image(systemName: "trash")
        }
        .tint(Color.danger)
        .accessibilityLabel("Revoke the invitation to \(invitation.email ?? "")")
        .buttonStyle(.borderless)
        .disabled(model.revoking != nil)
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

#Preview {
  NavigationStack {
    InvitationsScreen()
  }
  .environment(
    Session.stub(
      transport: StubTransport(routes: [
        "GET user/invitations": .json(
          #"{"data":[{"uuid":"019a4d5e-6f70-7182-9a3b-4c5d6e7f8a90","email":"sam@example.com","#
            + #""created_at":"2026-11-08T09:30:00Z","accepted_at":null,"revoked_at":null,"#
            + #""from_invite_link":false,"member_name":null},{"uuid":"#
            + #"019a4d5e-6f70-7182-9a3b-4c5d6e7f8a91","email":null,"#
            + #""created_at":"2026-11-02T18:00:00Z","accepted_at":"2026-11-02T18:00:00Z","#
            + #""revoked_at":null,"from_invite_link":true,"member_name":"Robin Diver"}],"#
            + #""total_count":2,"has_more":false,"page":1,"items_per_page":20}"#),
        "GET user/invite-link": .json(
          #"{"token":"q7Zr2LmWexampleInviteTokenNotReal0123456","#
            + #""created_at":"2026-11-01T10:00:00Z"}"#),
      ])))
}
