import OpenDivingKit
import SwiftUI

/// A record's links in its form: each an address over a label, in the diver's order, a row that
/// drags to a new place and swipes away, as the check-in sheet's emergency contacts are.
struct RecordLinksField: View {
  @Binding var links: [WebLinkRow]
  /// The sentence under a member of a row, `url` or `label`, or under the list for a nil row.
  let message: (_ row: Int?, _ member: String?) -> String?

  var body: some View {
    Section("Links") {
      SortableRows(
        items: $links, identity: \.id, title: title,
        row: { index, link in row(link.id, index: index, movable: links.count > 1) })
      if WebLinkRow.canAdd(to: links) {
        Button("Add a link") { links.append(WebLinkRow()) }
          .accentRow()
      }
      FieldMessage(message(nil, nil))
    }
  }

  private func title(_ link: WebLinkRow) -> String {
    let label = link.label.trimmingCharacters(in: .whitespaces)
    if !label.isEmpty { return label }
    let url = link.url.trimmingCharacters(in: .whitespaces)
    return url.isEmpty ? "Link" : url
  }

  private func row(_ id: UUID, index: Int, movable: Bool) -> some View {
    let link = binding(id)
    return VStack(alignment: .leading, spacing: 12) {
      TextBox(
        label: "Address", placeholder: "e.g. blueocean.com", text: link.url,
        message: message(index, "url"), keyboard: .URL, contentType: .URL, verbatim: true)
      TextBox(
        label: "Label", placeholder: "Booking, Instagram, manual…", text: link.label,
        message: message(index, "label"))
      HStack {
        Button("Remove") { links.removeAll { $0.id == id } }
          .dangerRow()
          .buttonStyle(.borderless)
          .accessibilityLabel("Remove \(title(link.wrappedValue))")
        Spacer()
        if movable { DragHandle() }
      }
    }
    .padding(.vertical, 4)
  }

  /// By identity, as the rows may have moved since the row drew.
  private func binding(_ id: UUID) -> Binding<WebLinkRow> {
    Binding(
      get: { links.first { $0.id == id } ?? WebLinkRow(id: id) },
      set: { link in
        guard let index = links.firstIndex(where: { $0.id == id }) else { return }
        links[index] = link
      })
  }
}

#Preview {
  @Previewable @State var links = [
    WebLinkRow(url: "https://blueocean.example", label: "Booking"), WebLinkRow(),
  ]
  Form {
    RecordLinksField(links: $links, message: { _, _ in nil })
  }
}
