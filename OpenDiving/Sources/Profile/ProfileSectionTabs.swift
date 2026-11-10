import OpenDivingKit
import SwiftUI

/// The profile's sections as tabs across the page: each an icon over its name, the chosen one in
/// full contrast over a coral underline, on a hairline that runs the page's width.
struct ProfileSectionTabs: View {
  @Binding var selection: ProfileSection

  @Namespace private var underline

  var body: some View {
    HStack(spacing: 0) {
      ForEach(ProfileSection.allCases, id: \.self) { section in
        tab(section)
      }
    }
    .padding(.horizontal)
    .background(alignment: .bottom) {
      Divider()
    }
  }

  private func tab(_ section: ProfileSection) -> some View {
    let isSelected = selection == section
    return Button {
      withAnimation(.easeOut(duration: 0.2)) { selection = section }
    } label: {
      VStack(spacing: 4) {
        // One height for every icon, so the names line up whatever each icon's own height.
        Image(section.icon)
          .font(.title2)
          .frame(height: 28)
        Text(section.title)
          .font(.subheadline.weight(.semibold))
      }
      .foregroundStyle(isSelected ? Color.primary : Color.secondary)
      .frame(maxWidth: .infinity)
      .padding(.bottom, 10)
      .overlay(alignment: .bottom) {
        if isSelected {
          Rectangle()
            .fill(Color.brandCoral)
            .frame(height: 3)
            .matchedGeometryEffect(id: "underline", in: underline)
        }
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

#Preview {
  @Previewable @State var selection = ProfileSection.dives
  ProfileSectionTabs(selection: $selection)
}
