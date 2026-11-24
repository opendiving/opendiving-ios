import SwiftUI

/// A form's one coral capsule, a row of its own the width of the form: a sign-in's or a
/// sign-up's. While `isBusy` the title is held in place under a spinner, so the button keeps its
/// size, and `busyValue` is what VoiceOver reads after the title.
struct FormCapsuleButton: View {
  let title: String
  let isBusy: Bool
  let busyValue: String
  let action: () -> Void
  @ScaledMetric(relativeTo: .body) private var spinnerSide: CGFloat = 24

  var body: some View {
    Button(action: action) {
      Text(title)
        .bold()
        .opacity(isBusy ? 0 : 1)
        .overlay {
          if isBusy {
            BubbleSpinner(side: spinnerSide, style: .white)
          }
        }
        .frame(maxWidth: .infinity)
    }
    .buttonStyle(.borderedProminent)
    .buttonBorderShape(.capsule)
    .tint(.brandCoral)
    .controlSize(.large)
    .accessibilityLabel(title)
    .accessibilityValue(isBusy ? busyValue : "")
    .listRowInsets(EdgeInsets())
    .listRowBackground(Color.clear)
  }
}

#Preview {
  Form {
    Section {
      FormCapsuleButton(title: "Sign in", isBusy: false, busyValue: "Sending") {}
    }
    Section {
      FormCapsuleButton(title: "Sign in", isBusy: true, busyValue: "Sending") {}
    }
  }
}
