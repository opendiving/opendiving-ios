import OpenDivingKit
import SwiftUI
import UIKit

/// A picture's slot as it stands, `width` across in the picture's shape: the edit pending or
/// just sent, else the stored picture, else the diver's initials or an empty frame. One gives way
/// to the next with a cross-fade. A host that sends each edit as it is chosen leaves out
/// `showsPending`, so the stored picture stays until the server has taken the new one.
struct PicturePreview: View {
  let model: PictureFieldModel
  let width: CGFloat
  var showsPending = true

  // Decoded as the body is drawn, rather than on a change after it, so no frame pairs the slot
  // with the previous picture's bytes.
  @State private var pending = Decoded()
  @State private var stored = Decoded()

  private var kind: PictureKind { model.kind }
  private var drawn: PictureEdit? { showsPending ? model.shown : model.sent }
  private var drawsStored: Bool { drawn == nil && model.storedSha != nil }

  /// Changes whenever the slot draws something else, which is what fades.
  private var showing: String {
    if drawn != nil { return "edit \(model.revision)" }
    guard let sha = model.storedSha else { return "none" }
    return "stored \(sha) \(model.storedData != nil)"
  }

  var body: some View {
    ZStack {
      picture
        .id(showing)
        .transition(.opacity)
    }
    .frame(width: width, height: width / kind.aspect)
    .clipShape(shape)
    .animation(.easeInOut(duration: 0.35), value: showing)
    .task(id: model.storedSha) { await model.loadStored() }
  }

  private var shape: AnyShape {
    kind == .avatar ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 8))
  }

  @ViewBuilder private var picture: some View {
    if let crop = drawn?.crop,
      let image = pending.image(model.revision, drawn?.source?.data)
    {
      CroppedPicture(image: image, crop: crop, width: width)
        .accessibilityLabel(showsPending ? "New \(kind.label)" : "Your \(kind.label)")
    } else if drawsStored,
      let image = stored.image(showing, model.storedData)
    {
      Image(uiImage: image)
        .resizable()
        .scaledToFill()
        .accessibilityLabel("Your \(kind.label)")
    } else if kind == .avatar {
      // A fill, not a ground: it shows on a list's row and on the page behind one alike.
      UserAvatarView(initials: model.initials, picture: nil, side: width)
        .background(Color(.tertiarySystemFill))
    } else {
      ZStack {
        Color(.secondarySystemBackground)
        Image(systemName: "person.crop.square")
          .font(.largeTitle)
          .foregroundStyle(.secondary)
      }
      .accessibilityElement()
      .accessibilityLabel(drawsStored ? "Your \(kind.label)" : "No \(kind.label)")
    }
  }
}

/// One picture decoded, kept until the key it was decoded under changes. Not observed: it only
/// remembers work the body has already asked for.
private final class Decoded {
  private var key: AnyHashable?
  private var decoded: UIImage?

  func image(_ key: AnyHashable, _ data: @autoclosure () -> Data?) -> UIImage? {
    if key != self.key {
      self.key = key
      decoded = data().flatMap(UIImage.init(data:))
    }
    return decoded
  }
}

/// A pending crop over its whole upright picture, drawn by placing the picture inside the frame
/// rather than by cutting it: the preview shows exactly the rectangle the server will be sent.
private struct CroppedPicture: View {
  let image: UIImage
  let crop: PictureCrop
  let width: CGFloat

  var body: some View {
    let scale = width / CGFloat(crop.width)
    Color.clear
      .overlay(alignment: .topLeading) {
        Image(uiImage: image)
          .resizable()
          .frame(
            width: image.size.width * image.scale * scale,
            height: image.size.height * image.scale * scale
          )
          .offset(x: -CGFloat(crop.x) * scale, y: -CGFloat(crop.y) * scale)
      }
      .clipped()
  }
}

#Preview {
  let session = Session.stub(transport: StubTransport(routes: [:]))
  HStack(spacing: 16) {
    PicturePreview(model: PictureFieldModel(kind: .avatar, session: session), width: 96)
    PicturePreview(model: PictureFieldModel(kind: .portrait, session: session), width: 96)
  }
}
