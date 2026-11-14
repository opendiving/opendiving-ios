import OpenDivingKit
import SwiftUI

/// One file the phone keeps: its name, its size, and where it stands — once uploaded, what the
/// server read it as, with the files a zip of it opened into beneath it. A file an import holds
/// cannot be removed until that import is settled.
struct ImportFileRow: View {
  let file: InboxFile

  @Environment(InboxModel.self) private var inbox

  var body: some View {
    let members = inbox.members(of: file)
    HStack(alignment: .top, spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        Text(file.filename)
          .font(.subheadline.weight(.medium))
        Text(DiveDetailText.fileSize(file.byteSize))
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
        Button("Remove \(file.filename)", systemImage: "trash") { inbox.remove(file) }
          .labelStyle(.iconOnly)
          .dangerRow()
          .buttonStyle(.borderless)
          .disabled(inbox.phase != .idle)
      }
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
