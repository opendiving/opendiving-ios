import OpenDivingKit
import SwiftUI

/// The profile's *More*: the rest of the logbook, a row each in the web's navigation order less
/// what the other tabs and the sites map hold, ruled off where the web's menu rules them. Each row
/// pushes its own screen, and the menu reads nothing of its own.
struct MoreMenu: View {
  var body: some View {
    VStack(spacing: 16) {
      ForEach(Array(MoreRow.sections.enumerated()), id: \.offset) { _, rows in
        VStack(spacing: 0) {
          ForEach(Array(rows.enumerated()), id: \.element) { index, row in
            if index > 0 {
              Divider().padding(.leading, 52)
            }
            NavigationLink {
              row.destination
            } label: {
              MoreRowLabel(row: row)
            }
            .buttonStyle(.plain)
          }
        }
        .background(Color.cardFill, in: .formSection)
      }
    }
  }
}

/// One of the menu's rows.
enum MoreRow: Hashable, CaseIterable {
  case aquaticLife, gear, certifications, courses, people, contacts

  /// The rows in their groups: the web's first rule falls before Gear.
  static let sections: [[MoreRow]] = [
    [.aquaticLife],
    [.gear, .certifications, .courses, .people, .contacts],
  ]

  var title: String {
    switch self {
    case .aquaticLife: "Aquatic Life"
    case .gear: "Gear"
    case .certifications: "Certifications"
    case .courses: "Courses"
    case .people: "People"
    case .contacts: "Contacts"
    }
  }

  var icon: OpenDivingKit.Icon {
    switch self {
    case .aquaticLife: .fish
    case .gear: .backpack
    case .certifications: .badgeCheck
    case .courses: .graduationCap
    case .people: .users
    case .contacts: .bookUser
    }
  }

  @ViewBuilder var destination: some View {
    switch self {
    case .aquaticLife: AquaticLifeListView()
    case .gear: GearListView()
    case .certifications: CertificationListView()
    case .courses: CourseListView()
    case .people: PeopleListView()
    case .contacts: ContactListView()
    }
  }
}

private struct MoreRowLabel: View {
  let row: MoreRow

  var body: some View {
    HStack(spacing: 12) {
      Image(row.icon)
        .foregroundStyle(.secondary)
        .frame(width: 24)
        .accessibilityHidden(true)
      Text(row.title)
      Spacer()
      Image(systemName: "chevron.right")
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.tertiary)
        .accessibilityHidden(true)
    }
    .padding(.horizontal, 16)
    .frame(minHeight: 48)
    .contentShape(Rectangle())
  }
}

#Preview {
  NavigationStack {
    ScrollView {
      MoreMenu()
        .padding()
    }
  }
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
