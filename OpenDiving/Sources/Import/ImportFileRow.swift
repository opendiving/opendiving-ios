import OpenDivingKit
import SwiftUI

/// One file the phone keeps: what a download holds or the file's name, its size, and where it
/// stands — once uploaded, what the server read it as, with the files a zip of it opened into
/// beneath it. A file an import holds cannot be removed until that import is settled.
struct ImportFileRow: View {
  let file: InboxFile

  @Environment(InboxModel.self) private var inbox
  @State private var confirming = false

  /// *12 dives from Shearwater Perdix 3, downloaded 25 October* for a download, the filename
  /// otherwise.
  static func title(_ file: InboxFile) -> String {
    file.download.map { DiveComputerText.inboxRow($0) } ?? file.filename
  }

  /// The trash button's label and, with a question mark, its confirmation's title: the row's
  /// own title, since a download's filename is a serial and a timestamp nobody reads.
  static func removeLabel(_ file: InboxFile) -> String { "Remove \(title(file))" }

  var body: some View {
    let members = inbox.members(of: file)
    HStack(alignment: .top, spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        Text(Self.title(file))
          .font(.subheadline.weight(.medium))
        Text(
          file.download == nil
            ? DiveDetailText.fileSize(file.byteSize)
            : file.filename + " · " + DiveDetailText.fileSize(file.byteSize)
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        if let own = members.own {
          let status = ImportText.memberStatus(own)
          StatusLine(text: status.text, refused: status.refused)
        } else {
          let stage = inbox.stage(of: file)
          StatusLine(text: PendingText.fileStage(stage), refused: stage.isRefused)
        }
        ForEach(Array(members.inside.enumerated()), id: \.offset) { _, child in
          let status = ImportText.memberStatus(child)
          VStack(alignment: .leading, spacing: 1) {
            Text(child.name).font(.footnote)
            StatusLine(text: status.text, refused: status.refused)
          }
          .padding(.leading, 12)
        }
      }
      Spacer(minLength: 0)
      if file.uploadedInto == nil {
        Button(Self.removeLabel(file), systemImage: "trash") {
          if inbox.removalNeedsConfirmation(file) {
            confirming = true
          } else {
            inbox.remove(file)
          }
        }
        .labelStyle(.iconOnly)
        .dangerRow()
        .buttonStyle(.borderless)
        .disabled(inbox.phase != .idle)
      }
    }
    .confirmationDialog(
      Self.removeLabel(file) + "?", isPresented: $confirming, titleVisibility: .visible
    ) {
      Button("Remove", role: .destructive) { inbox.remove(file) }
    } message: {
      Text(DiveComputerText.removeDownloadWarning)
    }
  }
}

private struct StatusLine: View {
  let text: String
  let refused: Bool

  var body: some View {
    Text(text)
      .font(.caption)
      .foregroundStyle(refused ? Color.danger : Color.secondary)
  }
}

#Preview {
  let session = Session.stub(transport: StubTransport(routes: [:]))
  List {
    ImportFileRow(file: InboxFile(filename: "dive-0214.fit", byteSize: 48_213))
  }
  .environment(InboxModel(session: session))
}
