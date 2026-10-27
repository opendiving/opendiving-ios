import OpenDivingKit
import SwiftUI

/// One waiting file: what a download holds or the file's name, its size, and once read, what the server read it as — or why
/// the bounds leave it out — with the files a zip of it opened into beneath it.
struct ImportFileRow: View {
  let file: InboxFile

  @Environment(InboxModel.self) private var inbox
  @State private var confirming = false

  /// *12 dives from Shearwater Perdix 3, downloaded 25 October* for a download, the filename
  /// otherwise.
  static func title(_ file: InboxFile) -> String {
    file.download.map { DiveComputerText.inboxRow($0) } ?? file.filename
  }

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
        if let refusal = inbox.refusal(for: file) {
          StatusLine(text: "Refused: " + refusal, refused: true)
        } else if let own = members.own {
          let status = ImportText.memberStatus(own)
          StatusLine(text: status.text, refused: status.refused)
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
      Button("Remove \(file.filename)", systemImage: "trash") {
        if inbox.removalNeedsConfirmation(file) {
          confirming = true
        } else {
          inbox.remove(file)
        }
      }
      .labelStyle(.iconOnly)
      .buttonStyle(.borderless)
      .disabled(inbox.phase != .idle)
    }
    .confirmationDialog(
      "Remove \(file.filename)?", isPresented: $confirming, titleVisibility: .visible
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
      .foregroundStyle(refused ? Color.red : Color.secondary)
  }
}

#Preview {
  let session = Session.stub(transport: StubTransport(routes: [:]))
  List {
    ImportFileRow(file: InboxFile(filename: "dive-0214.fit", byteSize: 48_213))
  }
  .environment(InboxModel(session: session))
}
