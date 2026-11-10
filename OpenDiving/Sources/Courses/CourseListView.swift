import OpenDivingKit
import SwiftUI

/// The diver's courses, in the API's order.
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
