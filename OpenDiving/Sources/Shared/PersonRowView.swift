import OpenDivingKit
import SwiftUI

/// One person on a dive, a trip or a course: the name, the linked account's `@username`,
/// and the role under them.
struct PersonRowView: View {
  let content: PersonRowContent

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Image(systemName: "person")
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
          Text(content.name)
            .font(.body.weight(.medium))
          if let username = content.username {
            Text("@\(username)")
              .foregroundStyle(.secondary)
          }
        }
        if let role = content.role {
          Text(role)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
    .accessibilityElement(children: .combine)
  }
}

#Preview {
  VStack(alignment: .leading) {
    PersonRowView(content: PersonRowContent(name: "Ana Diaz", username: "ana", role: "Buddy"))
    PersonRowView(content: PersonRowContent(name: "Sam Lee"))
  }
  .padding()
}
