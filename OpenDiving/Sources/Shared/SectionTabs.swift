import OpenDivingKit
import SwiftUI

/// What a page shows in tabs, each section under its own: the profile's, and an opened site's.
nonisolated protocol TabSection: Hashable, CaseIterable where AllCases: RandomAccessCollection {
  var title: String { get }
  /// What is drawn over the name, where a section has one.
  var icon: Icon? { get }
}

nonisolated extension TabSection {
  var icon: Icon? { nil }
}

/// A page's sections as tabs across it: each its name, under its icon where it has one and the
/// tabs show them, the chosen one in full contrast over a coral underline, on a hairline that
/// runs the page's width.
struct SectionTabs<Section: TabSection>: View {
  @Binding var selection: Section
  var showsIcons = true
  /// What a tab is called, where a count goes with its name.
  var title: (Section) -> String = { $0.title }

  /// How far the names sit below the tabs' top with the icons over them, beyond where they sit
  /// without, at the default text size: one height for every icon, so the names line up whatever
  /// each icon's own height. It scales with the icons' `title2`, wherever it is read.
  static var iconRowHeight: CGFloat { 28 }

  @ScaledMetric(relativeTo: .title2) private var iconRow = Self.iconRowHeight
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
      VStack(spacing: 0) {
        if showsIcons, let icon = section.icon {
          Image(icon)
            .font(.title2)
            .frame(height: iconRow)
        }
        Text(title(section))
          .lineLimit(1)
          // A count beside a long name still fits a third of a phone's width.
          .minimumScaleFactor(0.8)
          .font(.subheadline.weight(.semibold))
          .padding(.top, 4)
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
  VStack(spacing: 24) {
    SectionTabs(selection: $selection)
    SectionTabs(selection: $selection, showsIcons: false)
  }
}
