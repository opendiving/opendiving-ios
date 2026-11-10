import OpenDivingKit
import SwiftUI

/// A course's page, by its uuid.
/// A placeholder for now, which says the record is managed on the web.
struct CourseDetailView: View {
  let courseUUID: UUID

  var body: some View {
    ManagedOnTheWebView(
      title: "Course", icon: .graduationCap, message: "Courses are managed on the web.")
  }
}

#Preview {
  NavigationStack {
    CourseDetailView(courseUUID: UUID())
  }
}
