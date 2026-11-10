import OpenDivingKit
import SwiftUI

/// What a page shows in tabs, each section under its own: the profile's, and an opened site's.
nonisolated protocol TabSection: Hashable, CaseIterable where AllCases: RandomAccessCollection {
  var title: String { get }
  var icon: Icon { get }
}

/// A page's sections as tabs across it: each an icon over its name, the chosen one in full
/// contrast over a coral underline, on a hairline that runs the page's width.
struct SectionTabs<Section: TabSection>: View {
  @Binding var selection: Section

  @Namespace private var underline

  var body: some View {
    HStack(spacing: 0) {
      ForEach(Section.allCases, id: \.self) { section in
        tab(section)
      }
    }
    .padding(.horizontal)
    .background(alignment: .bottom) {
      Divider()
    }
  }

  private func tab(_ section: Section) -> some View {
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
  SectionTabs(selection: $selection)
}
