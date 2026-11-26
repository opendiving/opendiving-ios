import OpenDivingKit
import SwiftUI

/// *Sign in with a passkey*, under *Sign in*: bordered rather than a second coral capsule, the
/// width of the form, its label held in place under a spinner while the ceremony is out.
struct PasskeySignInButton: View {
  let isBusy: Bool
  let action: () -> Void
  @ScaledMetric(relativeTo: .body) private var spinnerSide: CGFloat = 24

  var body: some View {
    Button(action: action) {
      Label(SignInFlow.passkeyButton, icon: .keyRound)
        .opacity(isBusy ? 0 : 1)
        .overlay {
          if isBusy {
            BubbleSpinner(side: spinnerSide, style: Color.accentText)
          }
        }
        .frame(maxWidth: .infinity)
    }
    .brandBorderedButton()
    .buttonBorderShape(.capsule)
    .controlSize(.large)
    .accessibilityLabel(SignInFlow.passkeyButton)
    .accessibilityValue(isBusy ? "Signing in" : "")
    .listRowInsets(EdgeInsets())
    .listRowBackground(Color.clear)
  }
}

#Preview {
  Form {
    Section {
      PasskeySignInButton(isBusy: false) {}
    }
    Section {
      PasskeySignInButton(isBusy: true) {}
    }
  }
}
