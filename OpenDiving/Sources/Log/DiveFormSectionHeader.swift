import OpenDivingKit
import SwiftUI

/// A section's title led by its mark.
struct DiveFormSectionHeader: View {
  let group: DiveFormGroup

  var body: some View {
    HStack(spacing: 6) {
      Image(group.icon).accessibilityHidden(true)
      Text(group.title)
    }
  }
}

#Preview {
  Form {
    Section {
      Text("Row")
    } header: {
      DiveFormSectionHeader(group: .gear)
    }
  }
}
