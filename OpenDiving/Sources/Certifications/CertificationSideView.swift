import OpenDivingKit
import SwiftUI
import UIKit

/// The box a c-card is drawn in wherever one is drawn (`CertificationCardFrame`): the card's
/// shape, the app's corner, and whatever fills it clipped to that corner. A picture fills it, as
/// a card stored uncropped loses a sliver of its edge rather than sitting in a letterbox.
struct CertificationCardFrame<Content: View>: View {
  var isEmpty = false
  @ViewBuilder let content: Content

  static var aspect: CGFloat { CertificationCardCrop.aspect }

  var body: some View {
    Color(.secondarySystemFill)
      .aspectRatio(Self.aspect, contentMode: .fit)
      .frame(maxWidth: .infinity)
      .overlay { content }
      .clipShape(RoundedRectangle(cornerRadius: 10))
      .overlay {
        RoundedRectangle(cornerRadius: 10)
          .strokeBorder(
            Color(.separator), style: StrokeStyle(lineWidth: 1, dash: isEmpty ? [5] : []))
      }
  }
}

/// One stored side of a card (`CertificationCardImage`): its picture, kept once shown; a PDF as
/// a labelled file, never drawn; an empty side as a dashed frame.
struct CertificationSideView: View {
  let certificationUUID: UUID
  let file: CertificationFileInfo?
  var label = ""

  @Environment(Session.self) private var session
  @State private var image: UIImage?
  @State private var failed = false

  var body: some View {
    if let file {
      if file.contentType == CertificationCardEdits.pdfContentType {
        CertificationCardFrame {
          CertificationFileMark(icon: .fileText, text: "PDF")
        }
      } else {
        CertificationCardFrame {
          if let image {
            Image(uiImage: image)
              .resizable()
              .scaledToFill()
              .accessibilityLabel(label)
          } else if failed {
            CertificationFileMark(icon: .imageOff, text: "Couldn't load image")
          } else {
            BubbleSpinner()
          }
        }
        .task(id: file) { await load(file) }
      }
    } else {
      CertificationCardFrame(isEmpty: true) {
        Text(CertificationCardSlot.notUploaded)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }

  private func load(_ file: CertificationFileInfo) async {
    failed = false
    let bytes = await CertificationCardImages.bytes(
      of: certificationUUID, file, session: session)
    image = bytes.flatMap(UIImage.init(data:))
    failed = image == nil
  }
}

/// An icon and a word where a card has no picture to draw.
struct CertificationFileMark: View {
  let icon: OpenDivingKit.Icon
  let text: String

  var body: some View {
    VStack(spacing: 4) {
      Image(icon)
        .accessibilityHidden(true)
      Text(text)
        .font(.caption)
        .multilineTextAlignment(.center)
    }
    .foregroundStyle(.secondary)
    .padding(.horizontal, 8)
  }
}

#Preview {
  VStack {
    CertificationSideView(certificationUUID: UUID(), file: nil)
  }
  .padding()
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
