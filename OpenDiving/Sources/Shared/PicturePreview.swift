import OpenDivingKit
import SwiftUI
import UIKit

/// A picture's slot as it stands, `width` across in the picture's shape: the edit pending or
/// just landed, else the stored picture, else the diver's initials or an empty frame.
struct PicturePreview: View {
  let model: PictureFieldModel
  let width: CGFloat

  @State private var pending: UIImage?
  @State private var stored: UIImage?

  private var kind: PictureKind { model.kind }

  var body: some View {
    picture
      .frame(width: width, height: width / kind.aspect)
      .clipShape(shape)
      .task(id: model.storedSha) { await model.loadStored() }
      .onChange(of: model.storedData, initial: true) { _, data in
        stored = data.flatMap(UIImage.init(data:))
      }
      .onChange(of: model.revision, initial: true) {
        pending = model.shown?.source.flatMap { UIImage(data: $0.data) }
      }
  }

  private var shape: AnyShape {
    kind == .avatar ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 8))
  }

  @ViewBuilder private var picture: some View {
    if let crop = model.shown?.crop, let pending {
      CroppedPicture(image: pending, crop: crop, width: width)
        .accessibilityLabel("New \(kind.label)")
    } else if model.showsStored, let stored {
      Image(uiImage: stored)
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
      .accessibilityLabel(model.showsStored ? "Your \(kind.label)" : "No \(kind.label)")
    }
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
