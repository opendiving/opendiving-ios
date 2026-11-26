import SwiftUI

/// The rule between two rows on a list's card, drawn where a `List` draws its own: from where the
/// row's text starts to where its content ends, short of the card's trailing edge as well.
struct ListRowDivider: View {
  /// Where the row's text starts.
  let leading: CGFloat
  /// The row's own trailing padding, where its chevron or value ends.
  let trailing: CGFloat

  var body: some View {
    Divider()
      .padding(.leading, leading)
      .padding(.trailing, trailing)
  }
}

#Preview {
  VStack(spacing: 0) {
    Text("Gear").padding(16).frame(maxWidth: .infinity, alignment: .leading)
    ListRowDivider(leading: 16, trailing: 16)
    Text("Courses").padding(16).frame(maxWidth: .infinity, alignment: .leading)
  }
  .background(Color.cardFill, in: .formSection)
  .padding()
}
