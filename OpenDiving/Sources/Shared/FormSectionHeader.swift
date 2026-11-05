import OpenDivingKit
import SwiftUI

/// A form section's title led by its mark.
struct FormSectionHeader: View {
  let title: String
  let icon: Icon

  init(title: String, icon: Icon) {
    self.title = title
    self.icon = icon
  }

  /// A section of the dive form, or the same section of another form.
  init(group: DiveFormGroup) {
    self.init(title: group.title, icon: group.icon)
  }

  var body: some View {
    HStack(spacing: 6) {
      Image(icon).accessibilityHidden(true)
      Text(title)
    }
  }
}

#Preview {
  Form {
    Section {
      Text("Row")
    } header: {
      FormSectionHeader(group: .gear)
    }
  }
}
