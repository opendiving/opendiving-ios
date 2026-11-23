import OpenDivingKit
import SwiftUI

/// The head of a person form for an account: its picture, its name where the form is making the
/// connection, and its `@username`, none of which the form edits.
struct ConnectedAccountHead: View {
  let picture: ConnectedPicture?
  var name: String?
  let username: String

  var body: some View {
    HStack(spacing: 12) {
      ConnectedPictureView(picture: picture, side: 52)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        if let name {
          Text(name)
            .font(.headline)
        }
        Text("@" + username)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .accessibilityElement(children: .combine)
  }
}

#Preview {
  Form {
    ConnectedAccountHead(picture: nil, name: "Robin Diver", username: "robin")
    ConnectedAccountHead(picture: nil, username: "robin")
  }
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
