import OpenDivingKit
import SwiftUI

/// The profile's *More*: the rest of the logbook, a row each in the web's navigation order less
/// what the other tabs and the sites map hold, ruled off where the web's menu rules them, then the
/// import. Each row pushes its own screen, and the menu reads nothing of its own.
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
  case marineLife, gear, certifications, courses, people, contacts, imports

  /// The rows in their groups: the web's first rule falls before Gear, and the import follows,
  /// ruled off.
  static let sections: [[MoreRow]] = [
    [.marineLife],
    [.gear, .certifications, .courses, .people, .contacts],
    [.imports],
  ]

  var title: String {
    switch self {
    case .marineLife: "Marine Life"
    case .gear: "Gear"
    case .certifications: "Certifications"
    case .courses: "Courses"
    case .people: "People"
    case .contacts: "Contacts"
    case .imports: "Import"
    }
  }

  var icon: OpenDivingKit.Icon {
    switch self {
    case .marineLife: .fish
    case .gear: .backpack
    case .certifications: .badgeCheck
    case .courses: .graduationCap
    case .people: .users
    case .contacts: .bookUser
    case .imports: .upload
    }
  }

  @ViewBuilder var destination: some View {
    switch self {
    case .marineLife: MarineLifeListView()
    case .gear: GearListView()
    case .certifications: CertificationListView()
    case .courses: CourseListView()
    case .people: PeopleListView()
    case .contacts: ContactListView()
    case .imports: ImportView()
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
