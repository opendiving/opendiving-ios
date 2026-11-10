import OpenDivingKit
import SwiftUI

/// The diver's courses, in the API's order.
/// A placeholder for now, which says the record is managed on the web.
struct CourseListView: View {
  var body: some View {
    ManagedOnTheWebView(
      title: "Courses", icon: .graduationCap, message: "Courses are managed on the web.")
  }
}

#Preview {
  NavigationStack {
    CourseListView()
  }
}
