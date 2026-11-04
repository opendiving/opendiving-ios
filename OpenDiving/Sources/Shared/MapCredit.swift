import SwiftUI

/// The credit the instance's map owes, as a chip to lay over it.
struct MapCredit: View {
  let credit: String

  var body: some View {
    AttributionLine(credits: [credit], underline: false)
      .font(.system(size: 10))
      .padding(.horizontal, 4)
      .background(Color(.systemBackground).opacity(0.8), in: RoundedRectangle(cornerRadius: 2))
  }
}

#Preview {
  MapCredit(credit: "[OpenFreeMap](https://openfreemap.org/)")
}
