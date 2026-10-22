import SwiftUI

/// A stored rating as five stars, read out once as "4 of 5 stars".
struct RatingStars: View {
  static let maximum = 5
  let rating: Int

  var body: some View {
    HStack(spacing: 1) {
      ForEach(1...Self.maximum, id: \.self) { step in
        Image(systemName: step <= rating ? "star.fill" : "star")
          .foregroundStyle(step <= rating ? Color.orange : Color.secondary)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(rating) of \(Self.maximum) stars")
  }
}

#Preview {
  RatingStars(rating: 3)
    .padding()
}
