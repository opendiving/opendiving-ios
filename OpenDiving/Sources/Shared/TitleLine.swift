import SwiftUI

/// A record's name, followed by a graduation cap for a course dive and its rating in stars.
struct TitleLine: View {
  let title: String
  var isCourse = false
  var rating: Int?
  var font: Font = .headline

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 6) {
      Text(title)
        .font(font)
      if isCourse {
        Image(systemName: "graduationcap")
          .font(font)
          .accessibilityLabel("Training dive")
      }
      if let rating {
        RatingStars(rating: rating)
          .font(.caption)
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
