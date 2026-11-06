import OpenDivingKit
import SwiftUI

/// The credit the instance's map owes, as a chip to lay over it: legible, and quieter than the
/// map it sits on.
struct MapCredit: View {
  let credit: String

  var body: some View {
    AttributionLine(credits: [MapAttribution.display(credit)], underline: false)
      .font(.system(size: 10))
      .padding(.horizontal, 6)
      .padding(.vertical, 1)
      .background(Color(.systemBackground).opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
      .opacity(0.8)
  }
}

#Preview {
  MapCredit(credit: "[OpenFreeMap](https://openfreemap.org/)")
}
