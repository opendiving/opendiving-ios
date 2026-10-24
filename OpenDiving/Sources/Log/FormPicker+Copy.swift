import OpenDivingKit
import SwiftUI

// What each of the form's record pickers says, the web's words, and the sheet its *Add…* row
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
    case .cylinder: "Not linked to your gear"
    }
  }

  /// The row that creates a record of the picker's kind.
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

  /// The record sheet *Add…* opens, handing back the new record's ref.
  @ViewBuilder func addSheet(onCreated: @escaping (RecordRef) -> Void) -> some View {
    switch self {
    case .course: NewCourseSheet(onCreated: onCreated)
    case .trip: NewTripSheet(onCreated: onCreated)
    case .contact: NewContactSheet(onCreated: onCreated)
    case .diveSites: NewDiveSiteSheet(onCreated: onCreated)
    case .people: NewPersonSheet(onCreated: onCreated)
    case .gear: NewGearItemSheet(onCreated: onCreated)
    case .cylinder: NewGearItemSheet(type: "cylinder", onCreated: onCreated)
    }
  }
}
