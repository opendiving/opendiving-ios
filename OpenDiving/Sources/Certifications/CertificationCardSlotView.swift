import OpenDivingKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// One side of a card in the certification form: what it holds, what saving will do to it, and
/// its two controls. *Upload* or *Replace* takes a picture from the camera or the photo library,
/// framed to the card's shape before it is kept, or a file from Files — a PDF kept whole. Nothing
/// is sent from here: the form queues what the slots hold once it is saved.
struct CertificationCardSlotView: View {
  let certificationUUID: UUID?
  let slot: CertificationCardSlot
  let onPick: (CertificationCardPick) -> Void
  let onRemove: () -> Void
  /// Takes back a removal, or drops a picked image.
  let onUndo: () -> Void

  @State private var takingPhoto = false
  @State private var choosingPhoto = false
  @State private var choosingFile = false
  @State private var framing: FramedImage?
  @State private var refusal: Refusal?

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(slot.title)
        .font(.subheadline.weight(.medium))
      preview
      HStack(spacing: 12) {
        Menu {
          if CameraPicker.isAvailable {
            Button("Take Photo", systemImage: "camera") { takingPhoto = true }
          }
          Button("Photo Library", systemImage: "photo.on.rectangle") { choosingPhoto = true }
          Button("Choose File", systemImage: "folder") { choosingFile = true }
        } label: {
          Label(
            slot.primary,
            systemImage: slot.primary == "Upload" ? "square.and.arrow.up" : "arrow.2.squarepath")
        }
        .buttonStyle(.bordered)
        if let secondary = slot.secondary {
          Button {
            if case .remove = secondary { onRemove() } else { onUndo() }
          } label: {
            if case .keep = secondary {
              Image(systemName: "arrow.uturn.backward")
            } else {
              Image(systemName: "trash")
            }
          }
          .buttonStyle(.borderless)
          .accessibilityLabel(secondary.label)
        }
      }
      if let caption = slot.caption {
        Text(caption)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
    .fullScreenCover(isPresented: $takingPhoto) {
      CameraPicker { taken in
        takingPhoto = false
        if let taken { framing = FramedImage(image: taken) }
      }
      .ignoresSafeArea()
    }
    .photoLibraryPick(isPresented: $choosingPhoto) { data in
      if let data { frame(data) } else { refusal = .unreadable }
    }
    .fileImporter(
      isPresented: $choosingFile, allowedContentTypes: [.jpeg, .png, .webP, .pdf]
    ) { result in
      if case .success(let url) = result { loadFile(url) }
    }
    .sheet(item: $framing) { framed in
      CardFramingSheet(image: framed.image) { data in
        pick(.framed(data, side: slot.side))
      }
    }
    .alert(
      refusal?.title ?? "",
      isPresented: Binding(get: { refusal != nil }, set: { if !$0 { refusal = nil } })
    ) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(refusal?.message ?? "")
    }
  }

  @ViewBuilder private var preview: some View {
    switch slot.shown {
    case .stored(let file):
      // Only an edit's slot holds a stored file, and an edit has the uuid.
      if let certificationUUID {
        CertificationSideView(
          certificationUUID: certificationUUID, file: file,
          label: "\(slot.side.rawValue) of certification card")
      }
    case .empty:
      CertificationCardFrame(isEmpty: true) {
        Text(CertificationCardSlot.notUploaded)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .accessibilityElement()
      .accessibilityLabel(slot.emptyLabel)
    case .picked(let pick):
      CertificationCardFrame {
        if pick.isPDF {
          CertificationFileMark(icon: .fileText, text: "PDF")
        } else if let image = UIImage(data: pick.data) {
          Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .accessibilityLabel("New \(slot.side.rawValue) of certification card")
        }
      }
    }
  }

  private func loadFile(_ url: URL) {
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    // Checked before the bytes are read, as the web checks before it uploads.
    if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
      CertificationCardEdits.isTooLarge(size)
    {
      refusal = .tooLarge
      return
    }
    guard let data = try? Data(contentsOf: url) else {
      refusal = .unreadable
      return
    }
    if UTType(filenameExtension: url.pathExtension)?.conforms(to: .pdf) == true {
      pick(
        CertificationCardPick(
          data: data, contentType: CertificationCardEdits.pdfContentType,
          filename: url.lastPathComponent))
    } else {
      frame(data)
    }
  }

  /// Opens the framing over bytes the phone can draw, refusing what it cannot.
  private func frame(_ data: Data) {
    if CertificationCardEdits.isTooLarge(data.count) {
      refusal = .tooLarge
    } else if let image = UIImage(data: data) {
      framing = FramedImage(image: image)
    } else {
      refusal = .unreadable
    }
  }

  private func pick(_ pick: CertificationCardPick) {
    if CertificationCardEdits.isTooLarge(pick.data.count) {
      refusal = .tooLarge
    } else {
      onPick(pick)
    }
  }
}

private struct FramedImage: Identifiable {
  let id = UUID()
  let image: UIImage
}

private struct Refusal {
  let title: String
  let message: String

  static let tooLarge = Refusal(
    title: CertificationCardEdits.tooLargeTitle, message: CertificationCardEdits.tooLargeMessage)
  static let unreadable = Refusal(title: "Error", message: CertificationCardEdits.unreadable)
}

#Preview {
  Form {
    CertificationCardSlotView(
      certificationUUID: nil,
      slot: CertificationCardSlot(side: .front, stored: nil, edit: nil),
      onPick: { _ in }, onRemove: {}, onUndo: {})
  }
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
