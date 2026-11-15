import SwiftUI

/// A row that opens a page as a navigation link would, chevron and all, from a button: the
/// screen holds which page is open, for a `navigationDestination(item:)` and for whatever else
/// needs to know.
struct NavigationRow<Label: View>: View {
  let action: () -> Void
  @ViewBuilder let label: Label

  var body: some View {
    Button(action: action) {
      HStack {
        label
        Spacer(minLength: 0)
        Image(systemName: "chevron.right")
          .font(.footnote.weight(.semibold))
          .foregroundStyle(.tertiary)
          .accessibilityHidden(true)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(NavigationRowButtonStyle())
  }
}

/// Dims on a press and otherwise keeps the label's own colours, where the default style would
/// tint it as a button's.
private struct NavigationRowButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.opacity(configuration.isPressed ? 0.5 : 1)
  }
}

#Preview {
  List {
    NavigationRow {
    } label: {
      Text("Perdix 2")
    }
  }
}
