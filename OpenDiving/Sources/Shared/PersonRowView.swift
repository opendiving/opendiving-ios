import OpenDivingKit
import SwiftUI

/// One person on a dive, a trip or a course: the connected account's picture or the user icon,
/// the name, opening their page where the server has them, the connected account's `@username`,
/// and the role under them.
struct PersonRowView: View {
  let content: PersonRowContent

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      IconOrConnectedPicture(icon: .user, picture: content.picture)
      VStack(alignment: .leading, spacing: 2) {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
          if let uuid = content.uuid {
            NavigationLink(content.name) { PersonDetailView(personUUID: uuid) }
              .fontWeight(.medium)
              .accentRow()
          } else {
            Text(content.name)
              .fontWeight(.medium)
          }
          if let username = content.username {
            Text("@\(username)")
              .foregroundStyle(.secondary)
          }
        }
        if let role = content.role {
          Text(role)
            .foregroundStyle(.secondary)
        }
      }
    }
    // A dive's location card draws its places in the same size and colours.
    .font(.subheadline)
    .accessibilityElement(children: .combine)
  }
}

#Preview {
  VStack(alignment: .leading) {
    PersonRowView(content: PersonRowContent(name: "Ana Diaz", username: "ana", role: "Buddy"))
    PersonRowView(content: PersonRowContent(name: "Sam Lee"))
    PersonRowView(
      content: PersonRowContent(
        name: "Kai Moana", username: "kai",
        picture: ConnectedPicture(source: .person(UUID()), version: "ab12"), role: "Guide"))
  }
  .padding()
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
