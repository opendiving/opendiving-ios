import OpenDivingKit
import SwiftUI

/// *Sign in with a passkey*, under *Sign in*: bordered rather than a second coral capsule, the
/// width of the form, its label held in place under a spinner while the ceremony is out.
struct PasskeySignInButton: View {
  let isBusy: Bool
  let action: () -> Void
  @ScaledMetric(relativeTo: .body) private var spinnerSide: CGFloat = 24
  @ScaledMetric(relativeTo: .body) private var iconSide: CGFloat = 18
  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    Button(action: action) {
      label
        .opacity(isBusy ? 0 : 1)
        .overlay {
          if isBusy {
            BubbleSpinner(side: spinnerSide, style: Color.accentText)
          }
        }
        .frame(maxWidth: .infinity)
    }
    .brandBorderedButton()
    // A capsule's round ends cut into a label that wraps to several lines.
    .buttonBorderShape(typeSize.isAccessibilitySize ? .roundedRectangle : .capsule)
    .controlSize(.large)
    .accessibilityLabel(SignInFlow.passkeyButton)
    .accessibilityValue(isBusy ? "Signing in" : "")
    .listRowInsets(EdgeInsets())
    .listRowBackground(Color.clear)
  }

  // Beside the title at the accessibility sizes, the icon leaves the words too little width to
  // wrap between. Loaded, because a form row finds a symbol by name only in the system's set.
  @ViewBuilder private var label: some View {
    if typeSize.isAccessibilitySize {
      VStack(spacing: 6) {
        // A loaded symbol is a plain image, which the text size does not reach by itself.
        Image(loaded: .keyRound)
          .resizable()
          .scaledToFit()
          .frame(width: iconSide, height: iconSide)
        Text(SignInFlow.passkeyButton)
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
      }
    } else {
      Label {
        Text(SignInFlow.passkeyButton)
      } icon: {
        Image(loaded: .keyRound)
      }
    }
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

#Preview("Largest text") {
  Form {
    Section {
      PasskeySignInButton(isBusy: false) {}
    }
  }
  .dynamicTypeSize(.accessibility5)
}
