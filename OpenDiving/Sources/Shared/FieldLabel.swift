import SwiftUI

/// A field's label above its control, with what sits at its trailing edge — a unit toggle, a
/// clear — on the same line, so a row with one is as tall as a row without.
struct FieldLabel<Trailing: View>: View {
  let text: String
  @ViewBuilder let trailing: () -> Trailing

  init(_ text: String, @ViewBuilder trailing: @escaping () -> Trailing) {
    self.text = text
    self.trailing = trailing
  }

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      Text(text)
        .font(.subheadline.weight(.medium))
      Spacer(minLength: 8)
      trailing()
    }
  }
}

extension FieldLabel where Trailing == EmptyView {
  init(_ text: String) {
    self.init(text) { EmptyView() }
  }
}

#Preview {
  FieldLabel("Dive time *")
}
