import OpenDivingKit
import SwiftUI

// What each of the form's record pickers says, the web's words, and the sheet its +
// presents, by the initializers the record sheets keep.
extension FormPicker {
  /// The picker's prompt, which changes once a multi-select holds something.
  func placeholder(holdsSome: Bool) -> String {
    switch self {
    case .course: "Select a course..."
    case .trip: "Select a trip..."
    case .contact: "Select a dive center..."
    case .diveSites: holdsSome ? "Add another dive site..." : "Select a dive site..."
    case .people: holdsSome ? "Add another person..." : "Select a person..."
    case .gear: holdsSome ? "Add more gear..." : "Add gear..."
    case .cylinder: "Not linked"
    }
  }

  /// The prompt over the picker's sheet, where a cylinder's *Not linked* would not say what to do.
  var sheetPrompt: String {
    self == .cylinder ? "Select a cylinder..." : placeholder(holdsSome: false)
  }

  /// What the picker's search field asks for.
  var searchPrompt: String {
    switch self {
    case .course: "Search courses..."
    case .trip: "Search trips..."
    case .contact: "Search dive centers..."
    case .diveSites: "Search dive sites..."
    case .people: "Search people..."
    case .gear: "Search gear..."
    case .cylinder: "Search cylinders..."
    }
  }

  /// What the + that creates a record of the picker's kind is called.
  var addLabel: String {
    switch self {
    case .course: "Add course..."
    case .trip: "Add trip..."
    case .contact: "Add dive center..."
    case .diveSites: "Add dive site..."
    case .people: "Add person..."
    case .gear, .cylinder: "New gear item..."
    }
  }

  /// The record sheet the + opens, handing back the new record's ref, or the Commons record a
  /// site's sheet took instead.
  @ViewBuilder func addSheet(
    onCommonsSite: ((DiveSiteLookupItem) -> Void)? = nil,
    siteHandBack: SiteProposalHandBack = SiteProposalHandBack(),
    onCreated: @escaping (RecordRef) -> Void
  ) -> some View {
    switch self {
    case .course: NewCourseSheet(onCreated: onCreated)
    case .trip: NewTripSheet(onCreated: onCreated)
    case .contact: NewContactSheet(onCreated: onCreated)
    case .diveSites:
      NewDiveSiteSheet(
        onCommonsSite: onCommonsSite, handBack: siteHandBack, onCreated: onCreated)
    case .people: NewPersonSheet(onCreated: onCreated)
    case .gear: NewGearItemSheet(onCreated: onCreated)
    case .cylinder: NewGearItemSheet(type: "cylinder", onCreated: onCreated)
    }
  }
}
