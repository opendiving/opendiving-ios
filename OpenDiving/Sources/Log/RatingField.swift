import SwiftUI

/// The diver's rating as five stars, any one of which may be picked, and *Clear* for none —
/// unrated is an answer, not a zero.
struct RatingField: View {
  let rating: Int?
  var error: String?
  let onChange: (Int?) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      FieldLabel("Rating") {
        if rating != nil {
          Button("Clear") { onChange(nil) }
            .font(.caption)
            .buttonStyle(.borderless)
            .accessibilityLabel("Clear rating")
        }
      }
      HStack(spacing: 4) {
        ForEach(1...5, id: \.self) { step in
          Button {
            onChange(step)
          } label: {
            Image(systemName: step <= (rating ?? 0) ? "star.fill" : "star")
              .font(.title2)
              .foregroundStyle(step <= (rating ?? 0) ? Color.orange : Color.secondary)
              .frame(minWidth: 44, minHeight: 44)
          }
          .buttonStyle(.borderless)
          .accessibilityLabel(step == 1 ? "1 star" : "\(step) stars")
          .accessibilityAddTraits(step == rating ? .isSelected : [])
        }
      }
      if let error { FieldMessage(error) }
    }
  }
}

#Preview {
  Form {
    RatingField(rating: 4) { _ in }
  }
}
