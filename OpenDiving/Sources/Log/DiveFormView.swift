import OpenDivingKit
import SwiftUI

/// The dive form. Logging and editing on the phone arrive in a later version; until then it
/// says so, whichever dive it was opened on.
struct DiveFormView: View {
  let mode: DiveFormMode

  var body: some View {
    ContentUnavailableView {
      Label(title, systemImage: "square.and.pencil")
    } description: {
      Text(
        "Logging and editing dives on the phone arrive in a later version. Until then, use the web."
      )
    }
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.inline)
  }

  private var title: String {
    switch mode {
    case .create, .draft: "Log a dive"
    case .edit, .failed: "Edit dive"
    }
  }
}

#Preview("Log") {
  NavigationStack { DiveFormView(mode: .create) }
}

#Preview("Edit") {
  NavigationStack { DiveFormView(mode: .edit(UUID())) }
}
