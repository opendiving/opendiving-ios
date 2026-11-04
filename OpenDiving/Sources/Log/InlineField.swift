import SwiftUI

/// A one-line entry laid out as a select is: the label on the left, and at the right edge the box
/// with what belongs to it after it — a unit, a unit toggle.
struct InlineField<Field: View, Trailing: View>: View {
  let title: String
  @ViewBuilder let field: () -> Field
  @ViewBuilder let trailing: () -> Trailing

  init(
    _ title: String, @ViewBuilder field: @escaping () -> Field,
    @ViewBuilder trailing: @escaping () -> Trailing
  ) {
    self.title = title
    self.field = field
    self.trailing = trailing
  }

  var body: some View {
    HStack(spacing: 8) {
      Text(title)
        .layoutPriority(1)
        .accessibilityHidden(true)
      field()
        .multilineTextAlignment(.trailing)
        .frame(minWidth: 64)
        .accessibilityLabel(title)
      trailing()
    }
  }
}

extension InlineField where Trailing == EmptyView {
  init(_ title: String, @ViewBuilder field: @escaping () -> Field) {
    self.init(title, field: field) { EmptyView() }
  }
}

#Preview {
  @Previewable @State var text = "18"
  Form {
    InlineField("Maximum depth") {
      TextField("e.g. 30", text: $text)
    } trailing: {
      EntryUnitToggle(measure: .depth, current: .metric) {}
    }
    InlineField("Boat name") {
      TextField("e.g. Legend", text: .constant(""))
    }
  }
}
