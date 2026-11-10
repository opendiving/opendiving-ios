import OpenDivingKit
import SwiftUI

/// The course form as a screen of its own: a new course, a course's page's edit, or a queued edit
/// the server refused.
struct CourseFormView: View {
  let mode: RecordFormMode<CourseRead>
  /// The course was deleted from the form, which leaves its page nothing to show.
  var onDeleted: () -> Void = {}

  var body: some View {
    ManagedOnTheWebView(
      title: "Course", icon: .graduationCap, message: "Courses are managed on the web.")
  }
}

#Preview {
  NavigationStack {
    CourseFormView(mode: .create)
  }
}
