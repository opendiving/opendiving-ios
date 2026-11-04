import SwiftUI

/// A one-line entry laid out as a select is: the label on the left, which focuses the box when
/// tapped, and at the right edge the box with what belongs to it after it — a unit, a unit toggle.
struct InlineField<Field: View, Trailing: View>: View {
  let title: String
  let focus: FocusState<Bool>.Binding
  @ViewBuilder let field: () -> Field
  @ViewBuilder let trailing: () -> Trailing

  init(
    _ title: String, focus: FocusState<Bool>.Binding, @ViewBuilder field: @escaping () -> Field,
    @ViewBuilder trailing: @escaping () -> Trailing
  ) {
    self.title = title
    self.focus = focus
    self.field = field
    self.trailing = trailing
  }

  var body: some View {
    HStack(spacing: 8) {
      Text(title)
        .layoutPriority(1)
        .contentShape(Rectangle())
        .onTapGesture { focus.wrappedValue = true }
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
  init(
    _ title: String, focus: FocusState<Bool>.Binding, @ViewBuilder field: @escaping () -> Field
  ) {
    self.init(title, focus: focus, field: field) { EmptyView() }
  }
}

#Preview {
  @Previewable @State var text = "18"
  @Previewable @FocusState var focused: Bool
  Form {
    InlineField("Maximum depth", focus: $focused) {
      TextField("e.g. 30", text: $text).focused($focused)
    } trailing: {
      EntryUnitToggle(measure: .depth, current: .metric) {}
    }
  }
}
