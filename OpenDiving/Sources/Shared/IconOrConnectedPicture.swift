import OpenDivingKit
import SwiftUI

/// A row's symbol at the size its font draws it, or a connected person's picture in the symbol's
/// frame: the picture takes the icon's size, slot and baseline, so rows with and without one start
/// their text at one edge and centre the circle where the icon sits.
struct IconOrConnectedPicture: View {
  let icon: OpenDivingKit.Icon
  let picture: ConnectedPicture?

  var body: some View {
    // The icon stays in the layout under a picture, which is what sizes and places it.
    Image(icon)
      .foregroundStyle(.secondary)
      .opacity(picture == nil ? 1 : 0)
      .overlay {
        if let picture {
          GeometryReader { proxy in
            // Lucide keeps a 2-unit margin inside its 24-unit grid, so the icon's strokes fill
            // 20 units of its frame and the picture fills the same.
            ConnectedPictureView(
              picture: picture, side: min(proxy.size.width, proxy.size.height) * 20 / 24
            )
            .frame(width: proxy.size.width, height: proxy.size.height)
          }
        }
      }
      .accessibilityHidden(true)
  }
}

#Preview {
  VStack(alignment: .leading, spacing: 12) {
    ForEach([Font.subheadline, .body], id: \.self) { font in
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        IconOrConnectedPicture(icon: .user, picture: nil)
        Text("Sam Lee")
      }
      .font(font)
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        IconOrConnectedPicture(
          icon: .user, picture: ConnectedPicture(source: .person(UUID()), version: "ab12"))
        Text("Ana Diaz")
      }
      .font(font)
    }
  }
  .padding()
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
