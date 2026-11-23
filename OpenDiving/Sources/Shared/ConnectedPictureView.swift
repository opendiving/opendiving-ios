import OpenDivingKit
import SwiftUI

/// A connected account's picture in a circle `side` across, or the plain user icon where it has
/// none or is not to hand yet: a connected person without a picture looks like any other.
struct ConnectedPictureView: View {
  let picture: ConnectedPicture?
  let side: CGFloat

  @Environment(Session.self) private var session
  @State private var data: Data?

  var body: some View {
    UserAvatarView(initials: nil, picture: data, side: side)
      .foregroundStyle(.secondary)
      .background(Color(.tertiarySystemFill), in: Circle())
      .task(id: picture) {
        data = nil
        guard let picture else { return }
        data = await ConnectedPictures.picture(picture, session: session)
      }
  }
}

#Preview {
  HStack(spacing: 16) {
    ConnectedPictureView(picture: nil, side: 36)
    ConnectedPictureView(
      picture: ConnectedPicture(source: .person(UUID()), version: "ab12"), side: 52)
  }
  .padding()
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
