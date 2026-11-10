import OpenDivingKit
import SwiftUI

/// The Sites map's weather bar where the server could not be reached for the weather.
struct MapWeatherOfflineBar: View {
  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: "wifi.slash")
      Text(OfflineText.noConnection)
    }
    .foregroundStyle(.secondary)
    .mapWeatherBarChrome()
    .accessibilityElement(children: .combine)
  }
}

#Preview {
  NavigationStack {
    Color.teal.opacity(0.3)
      .ignoresSafeArea()
      .toolbar {
        ToolbarItem(placement: .principal) { MapWeatherOfflineBar() }
      }
  }
}
