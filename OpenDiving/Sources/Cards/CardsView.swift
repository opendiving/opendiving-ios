import OpenDivingKit
import SwiftUI

/// The *Cards* tab: the check-in sheet, which is also shown signed out. Placeholder.
struct CardsView: View {
  var body: some View {
    NavigationStack {
      EmptyOrErrorView(
        status: .empty(
          systemImage: "person.text.rectangle", title: "Check-in sheet",
          message: "Not built yet.")
      )
      .navigationTitle("Cards")
    }
  }
}

#Preview {
  CardsView()
}
