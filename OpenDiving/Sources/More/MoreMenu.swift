import OpenDivingKit
import SwiftUI

/// The profile's *More*: the rest of the logbook, a row each in the web's navigation order less
/// what the other tabs hold, ruled off where the web's menu rules them, then the import and,
/// where the instance takes them, the diver's proposals for OpenDiving Commons. Each row pushes
/// its own screen, and the menu reads nothing of its own.
struct MoreMenu: View {
  let isCommonsPrimary: Bool

  var body: some View {
    VStack(spacing: 16) {
      ForEach(
        Array(MoreRow.sections(isCommonsPrimary: isCommonsPrimary).enumerated()), id: \.offset
      ) { _, rows in
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
  case diveSites, marineLife, gear, certifications, courses, people, contacts, imports, proposals

  /// The rows in their groups: the web's first rule falls before Gear, and the import and the
  /// proposals follow, ruled off. The proposals' routes answer only on an instance that edits
  /// the Commons.
  static func sections(isCommonsPrimary: Bool) -> [[MoreRow]] {
    [
      [.diveSites, .marineLife],
      [.gear, .certifications, .courses, .people, .contacts],
      isCommonsPrimary ? [.imports, .proposals] : [.imports],
    ]
  }

  var title: String {
    switch self {
    case .diveSites: "Dive Sites"
    case .marineLife: "Marine Life"
    case .gear: "Gear"
    case .certifications: "Certifications"
    case .courses: "Courses"
    case .people: "People"
    case .contacts: "Contacts"
    case .imports: "Import"
    case .proposals: YourProposalsView.title
    }
  }

  /// The row's symbol; nil for the proposals, which draw the Commons' own mark.
  var icon: OpenDivingKit.Icon? {
    switch self {
    case .diveSites: .diveSite
    case .marineLife: .fish
    case .gear: .backpack
    case .certifications: .badgeCheck
    case .courses: .graduationCap
    case .people: .users
    case .contacts: .bookUser
    case .imports: .upload
    case .proposals: nil
    }
  }

  @ViewBuilder var destination: some View {
    switch self {
    case .diveSites: YourDiveSitesView()
    case .marineLife: MarineLifeListView()
    case .gear: GearListView()
    case .certifications: CertificationListView()
    case .courses: CourseListView()
    case .people: PeopleListView()
    case .contacts: ContactListView()
    case .imports: ImportView()
    case .proposals: YourProposalsView()
    }
  }
}

private struct MoreRowLabel: View {
  let row: MoreRow

  var body: some View {
    HStack(spacing: 12) {
      Group {
        if let icon = row.icon {
          Image(icon)
            .foregroundStyle(.secondary)
        } else {
          CommonsMark(side: 18, relativeTo: .body)
        }
      }
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
      MoreMenu(isCommonsPrimary: true)
        .padding()
    }
  }
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
