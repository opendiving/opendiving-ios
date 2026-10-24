import OpenDivingKit
import SwiftUI

/// One waiting file: its name and size, and once read, what the server read it as — or why
/// the bounds leave it out — with the files a zip of it opened into beneath it.
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
      Button("Remove \(file.filename)", systemImage: "trash") { inbox.remove(file) }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .disabled(inbox.phase != .idle)
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
