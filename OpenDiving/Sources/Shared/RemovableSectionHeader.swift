import OpenDivingKit
import SwiftUI

/// A section's title with the bin that removes what it heads: a trip's part under its mark, a
/// dive's tank, which is drawn as what it records.
struct RemovableSectionHeader: View {
  let title: String
  var icon: Icon?
  var tank: TankIcon?
  let onRemove: () -> Void

  var body: some View {
    HStack {
      if let icon {
        FormSectionHeader(title: title, icon: icon)
      } else {
        if let tank {
          TankIconView(icon: tank).frame(width: 20, height: 20)
        }
        Text(title)
      }
      Spacer()
      Button(role: .destructive, action: onRemove) {
        Image(systemName: "trash").foregroundStyle(Color.danger)
      }
      .buttonStyle(.borderless)
      .accessibilityLabel("Remove \(title.lowercased())")
    }
  }
}

#Preview {
  Form {
    Section {
      Text("Row")
    } header: {
      RemovableSectionHeader(title: "Part 1", icon: .mapPin) {}
    }
  }
}
