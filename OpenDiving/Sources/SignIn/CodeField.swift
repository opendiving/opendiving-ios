import OpenDivingKit
import SwiftUI

/// Six boxes over one hidden field, so that typing, pasting and the keyboard's one-time-code
/// suggestion all land in the same place.
struct CodeField: View {
  @Binding var code: String
  @FocusState private var isFocused: Bool

  var body: some View {
    ZStack {
      TextField("", text: $code)
        .keyboardType(.numberPad)
        .textContentType(.oneTimeCode)
        .focused($isFocused)
        .foregroundStyle(.clear)
        .tint(.clear)
        .accessibilityLabel("Sign-in code")
      HStack(spacing: 8) {
        ForEach(0..<SignInFlow.codeLength, id: \.self) { index in
          box(index)
        }
      }
      .allowsHitTesting(false)
      .accessibilityHidden(true)
    }
    .contentShape(Rectangle())
    .onTapGesture { isFocused = true }
    .onAppear { isFocused = true }
  }

  private func box(_ index: Int) -> some View {
    let digits = Array(code)
    let digit = index < digits.count ? String(digits[index]) : ""
    let isNext = isFocused && index == min(digits.count, SignInFlow.codeLength - 1)
    return Text(digit)
      .font(.title2.monospacedDigit().weight(.semibold))
      .frame(maxWidth: .infinity, minHeight: 52)
      .background(RoundedRectangle(cornerRadius: 10).fill(.fill.tertiary))
      .overlay(
        RoundedRectangle(cornerRadius: 10)
          .strokeBorder(isNext ? Color.accentColor : .clear, lineWidth: 2))
  }
}

#Preview {
  @Previewable @State var code = "123"
  CodeField(code: $code)
    .padding()
}
