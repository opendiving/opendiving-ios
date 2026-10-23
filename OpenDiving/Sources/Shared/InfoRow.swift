import SwiftUI

/// One labelled fact in a record's info card: a muted label over its value. The caller
/// leaves the row out where the record holds no value, as the web's `InfoRow` is only ever
/// rendered conditionally.
struct InfoRow<Content: View>: View {
  let label: String
  let content: Content

  init(label: String, @ViewBuilder content: () -> Content) {
    self.label = label
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(label)
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.secondary)
      content
        .font(.subheadline)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }
}

#Preview {
  VStack(alignment: .leading, spacing: 16) {
    InfoRow(label: "Also known as") {
      Text("Bells, The Bells")
    }
    InfoRow(label: "Tags") {
      HStack {
        BadgeView("wall", style: .outline)
        BadgeView("drift", style: .outline)
      }
    }
  }
  .padding()
}
