import OpenDivingKit
import SwiftUI

/// The box a c-card is drawn in wherever one is drawn — the check-in sheet, More's certifications
/// and the certification form (`CertificationCardFrame`): the card's shape, the app's corner, and
/// whatever fills it clipped to that corner. A picture fills it, as a card stored uncropped loses a
/// sliver of its edge rather than sitting in a letterbox.
struct CertificationCardFrame<Content: View>: View {
  var isEmpty = false
  @ViewBuilder let content: Content

  static var aspect: CGFloat { CertificationCardCrop.aspect }

  var body: some View {
    Color(.secondarySystemFill)
      .aspectRatio(Self.aspect, contentMode: .fit)
      .frame(maxWidth: .infinity)
      .overlay { content }
      .clipShape(RoundedRectangle(cornerRadius: 10))
      .overlay {
        RoundedRectangle(cornerRadius: 10)
          .strokeBorder(
            Color(.separator), style: StrokeStyle(lineWidth: 1, dash: isEmpty ? [5] : []))
      }
  }
}

#Preview {
  VStack {
    CertificationCardFrame { Text("Front") }
    CertificationCardFrame(isEmpty: true) { Text("Not uploaded") }
  }
  .padding()
}
