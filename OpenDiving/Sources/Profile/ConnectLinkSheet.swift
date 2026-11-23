import OpenDivingKit
import SwiftUI

/// The profile's QR button's pane: the diver's connect link as a QR code to show, its reset and
/// removal under it and the share in the top bar, or the way to make one while there is none.
struct ConnectLinkSheet: View {
  @Environment(Session.self) private var session

  var body: some View {
    ConnectLinkPane(session: session)
  }
}

private struct ConnectLinkPane: View {
  @Environment(Session.self) private var session
  @State private var model: ConnectLinkModel
  @Environment(\.dismiss) private var dismiss

  init(session: Session) {
    _model = State(initialValue: ConnectLinkModel(session: session))
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
      .navigationTitle(ConnectLinkModel.title)
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
    // Whether the instance admits only those invited, which the pane's note depends on.
    .task { await session.loadServerInfo() }
  }

  @ViewBuilder private var content: some View {
    // Read again each time the pane opens; a read that fails leaves the phone's copy dated.
    if let lastUpdated = model.lastUpdated {
      LastUpdatedLine(date: lastUpdated)
    }
    if !model.isLinkRead {
      if let failure = model.linkLoadFailure {
        Text(ConnectLinkModel.linkLoadFailed + " " + failure)
          .foregroundStyle(.secondary)
        Button("Try again") { Task { await model.load() } }
          .needsServer()
          .accentRow()
      } else {
        HStack {
          BubbleSpinner()
          Text(ConnectLinkModel.loading)
        }
        .foregroundStyle(.secondary)
      }
    } else if let address = model.linkAddress {
      ConnectQRCode(address: address.absoluteString, label: ConnectLinkModel.qrLabel)
      note(ConnectLinkModel.linkLive)
      if let instance = model.instanceNote {
        note(instance)
      }
      HStack(spacing: 12) {
        changeButton(.reset)
        changeButton(.remove)
      }
      .controlSize(.large)
      failure
    } else {
      Text(ConnectLinkModel.linkNone)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
      if let instance = model.instanceNote {
        note(instance)
      }
      Button {
        Task { await model.createLink() }
      } label: {
        Label(ConnectLinkModel.linkCreate, systemImage: "link")
          .frame(maxWidth: .infinity)
      }
      .brandProminentButton()
      .controlSize(.large)
      .disabled(model.isChangingLink)
      .needsServer()
      failure
    }
  }

  private func note(_ text: String) -> some View {
    Text(text)
      .font(.footnote)
      .foregroundStyle(.secondary)
      .multilineTextAlignment(.center)
  }

  @ViewBuilder private var failure: some View {
    if model.isChangingLink {
      BubbleSpinner()
    } else if let failure = model.linkFailure {
      FieldMessage(failure)
    }
  }

  private func changeButton(_ change: ConnectLinkModel.LinkChange) -> some View {
    let isRemoval = change == .remove
    return Button(role: isRemoval ? .destructive : nil) {
      model.askToConfirm(change)
    } label: {
      Label(
        isRemoval ? ConnectLinkModel.removeButton : ConnectLinkModel.resetButton,
        systemImage: isRemoval ? "trash" : "arrow.counterclockwise"
      )
      .frame(maxWidth: .infinity)
    }
    .brandBorderedButton(isRemoval ? .danger : .accentText)
    .disabled(model.isChangingLink)
    .needsServer()
    .confirmsConnectLinkChange(change, model: model)
  }
}

#Preview {
  Color.clear
    .sheet(isPresented: .constant(true)) { ConnectLinkSheet() }
    .environment(
      Session.stub(
        transport: StubTransport(routes: [
          "GET user/connect-link": .json(
            #"{"token":"9f86d081884c7d659a2feaa0c55ad015","#
              + #""created_at":"2026-11-01T10:00:00Z"}"#)
        ])))
}
