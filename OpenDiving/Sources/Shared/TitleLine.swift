import SwiftUI

/// A record's name, followed by a graduation cap for a course dive, its rating in stars and a
/// badge, as a certification's expiry.
struct TitleLine: View {
  let title: String
  var isCourse = false
  var rating: Int?
  var badge: Badge?
  var font: Font = .headline

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 6) {
      Text(title)
        .font(font)
      if isCourse {
        Image(.graduationCap)
          .font(font)
          .accessibilityLabel("Training dive")
      }
      if let rating {
        RatingStars(rating: rating)
          .font(.caption)
      }
      if let badge {
        BadgeView(badge)
      }
    }
  }
}

#Preview {
  VStack(alignment: .leading) {
    TitleLine(title: "#212 Blue Hole", isCourse: true, rating: 4)
    TitleLine(title: "#211 The Canyon")
  }
  .padding()
}
