import OpenDivingKit
import SwiftUI

/// Above what a list or a page shows from the phone's copy: when that copy was fetched. It
/// goes once the fetch behind it lands.
struct LastUpdatedLine: View {
  let date: Date

  var body: some View {
    Label(OfflineText.lastUpdated(date), systemImage: "clock.arrow.circlepath")
      .font(.footnote)
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

#Preview {
  LastUpdatedLine(date: Date(timeIntervalSinceNow: -3600))
    .padding()
}
