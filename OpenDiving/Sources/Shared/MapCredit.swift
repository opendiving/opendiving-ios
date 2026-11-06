import OpenDivingKit
import SwiftUI

/// The credit the instance's map owes, to lay over it: bare text, quieter than the map it sits on.
struct MapCredit: View {
  let credit: String

  var body: some View {
    AttributionLine(credits: [MapAttribution.display(credit)], underline: false)
      .font(.system(size: 10))
      .opacity(0.8)
  }
}

#Preview {
  MapCredit(credit: "[OpenFreeMap](https://openfreemap.org/)")
}
