import OpenDivingKit
import SwiftUI

/// The profile's *New*: every record the phone makes, a pick pushing its form.
struct CreateMenu: View {
  let onPick: (CreateItem) -> Void

  var body: some View {
    Menu {
      ForEach(Array(CreateItem.sections.enumerated()), id: \.offset) { _, items in
        Section {
          ForEach(items, id: \.self) { item in
            Button {
              onPick(item)
            } label: {
              Label(menuItem: item.title, icon: item.icon)
            }
          }
        }
      }
    } label: {
      Label("New", systemImage: "plus")
    }
  }
}

/// One of the records `CreateMenu` makes.
enum CreateItem: Hashable, CaseIterable {
  case dive, trip, diveSite, gear, gearSet, certification, course, person, contact

  /// The web's create menu first, then what it makes only from a record's own list, ruled off
  /// where the web's navigation rules Gear off from the sites.
  static let sections: [[CreateItem]] = [
    [.dive, .trip, .diveSite],
    [.gear, .gearSet, .certification, .course, .person, .contact],
  ]

  var title: String {
    switch self {
    case .dive: "New dive"
    case .trip: "New trip"
    case .diveSite: "New dive site"
    case .gear: "New gear"
    case .gearSet: "New gear set"
    case .certification: "New certification"
    case .course: "New course"
    case .person: "New person"
    case .contact: "New contact"
    }
  }

  /// The icon the record's tab or *More* row has.
  var icon: Icon {
    switch self {
    case .dive: .dive
    case .trip: .luggage
    case .diveSite: .diveSite
    case .gear: .backpack
    case .gearSet: .layers
    case .certification: .badgeCheck
    case .course: .graduationCap
    case .person: .users
    case .contact: .bookUser
    }
  }

  @ViewBuilder var destination: some View {
    switch self {
    case .dive: DiveFormView(mode: .create)
    case .trip: TripFormView(mode: .create)
    case .diveSite: DiveSiteFormView(mode: .create)
    case .gear: GearItemFormView(mode: .create)
    case .gearSet: GearSetFormView(mode: .create)
    case .certification: CertificationFormView(mode: .create)
    case .course: CourseFormView(mode: .create)
    case .person: PersonFormView(mode: .create)
    case .contact: ContactFormView(mode: .create)
    }
  }
}

#Preview {
  NavigationStack {
    Color.pageBackground
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) { CreateMenu { _ in } }
      }
  }
}
