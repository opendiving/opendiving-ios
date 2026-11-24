import OpenDivingKit
import SwiftUI

/// Somebody's connect link, opened signed in: the form that adds its owner, headed by their
/// picture, name and username, or else that the link is no longer active, that it is the diver's
/// own, or that its owner is in their people already, as the web's page says each.
struct ConnectLinkOpenView: View {
  let token: String
  @Environment(Session.self) private var session

  var body: some View {
    ConnectLinkOpenContent(model: ConnectLinkOpenModel(session: session, token: token))
  }
}

private struct ConnectLinkOpenContent: View {
  @State var model: ConnectLinkOpenModel
  @State private var showingOwnLink = false
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      Group {
        if case .connect(let owner) = model.phase {
          ConnectPersonForm(model: model.form(owner))
        } else {
          ScrollView {
            VStack(spacing: 12) {
              status
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .padding()
          }
          .navigationTitle(ConnectLinkOpenModel.title)
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
            ToolbarItem(placement: .topBarLeading) {
              Button("Close", systemImage: "xmark") { dismiss() }
            }
          }
        }
      }
    }
    .task { await model.show() }
    .sheet(isPresented: $showingOwnLink) { ConnectLinkSheet() }
  }

  @ViewBuilder private var status: some View {
    switch model.phase {
    case .loading, .connect:
      HStack {
        BubbleSpinner()
        Text(ConnectLinkOpenModel.loading)
      }
      .foregroundStyle(.secondary)
    case .noRoute:
      Text(ConnectLinkOpenModel.noRoute)
        .foregroundStyle(.secondary)
    case .failed(let message):
      title(ConnectLinkOpenModel.failedTitle)
      Text(message)
        .foregroundStyle(.secondary)
      Button("Try again") { Task { await model.load() } }
        .brandBorderedButton()
        .needsServer()
    case .gone:
      title(ConnectLinkOpenModel.goneTitle)
      Text(ConnectLinkOpenModel.goneMessage)
        .foregroundStyle(.secondary)
    case .yours(let owner):
      picture(owner)
      title(ConnectLinkOpenModel.yoursTitle)
      Text(ConnectLinkOpenModel.yoursMessage)
        .foregroundStyle(.secondary)
      Button(ConnectLinkOpenModel.openYours) { showingOwnLink = true }
        .brandBorderedButton()
    case .alreadyIn(let person, let owner):
      picture(owner)
      title(ConnectLinkOpenModel.alreadyInTitle(owner))
      Text(ConnectLinkOpenModel.alreadyInMessage(owner))
        .foregroundStyle(.secondary)
      NavigationLink(ConnectLinkOpenModel.goTo(owner)) {
        PersonDetailView(personUUID: person)
      }
      .brandBorderedButton()
    }
  }

  private func title(_ text: String) -> some View {
    Text(text)
      .font(.title2.bold())
  }

  private func picture(_ owner: ConnectLinkOwnerForYou) -> some View {
    ConnectedPictureView(picture: model.picture(owner), side: 72)
      .accessibilityHidden(true)
  }
}

#Preview("A link to add") {
  ConnectLinkOpenView(token: "abc")
    .environment(
      Session.stub(
        transport: StubTransport(routes: [
          "GET connect-link/abc/owner": .json(
            #"{"name":"Robin Diver","username":"robin","avatar_sha256":null,"#
              + #""is_yours":false,"person_uuid":null}"#)
        ]))
    )
    .environment(ScreenPresenter())
}

#Preview("No longer active") {
  ConnectLinkOpenView(token: "abc")
    .environment(Session.stub(transport: StubTransport(routes: [:])))
    .environment(ScreenPresenter())
}
