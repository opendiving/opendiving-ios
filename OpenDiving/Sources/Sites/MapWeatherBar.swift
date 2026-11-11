import OpenDivingKit
import SwiftUI

/// The weather at a site on the Sites map, in its top bar: the sky, the air temperature, the wind
/// with an arrow along it and the sea's temperature. A tap grows it into ``MapWeatherCard``, the
/// whole reading, and a pull down grows it as far as the finger goes.
struct MapWeatherBar: View {
  let content: MapWeatherContent
  let onTap: () -> Void
  /// How far a finger has pulled the bar down.
  var onPull: (CGFloat) -> Void = { _ in }
  /// The finger lifted, its pull heading for that far down; nil where the system cut it short.
  var onPullEnded: (CGFloat?) -> Void = { _ in }
  @GestureState private var isPulling = false

  var body: some View {
    // Not a `Button`: the bar draws a button's label as its title or its icon alone, never both.
    MapWeatherBarLabel(content: content)
      .mapWeatherBarChrome()
      .onTapGesture(perform: onTap)
      // Down, as the card it opens hangs below it. On the window, since what follows the finger is
      // drawn over the bar, not in it.
      .gesture(
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
          .updating($isPulling) { _, pulling, _ in pulling = true }
          .onChanged { onPull($0.translation.height) }
          .onEnded { onPullEnded($0.predictedEndTranslation.height) }
      )
      // A pull ended without `onEnded`, as the presentation it opens may end it, still finishes.
      .onChange(of: isPulling) { _, pulling in
        if !pulling { onPullEnded(nil) }
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(content.accessibilityLabel)
      .accessibilityHint("Shows the whole reading and where it is from")
      .accessibilityAddTraits(.isButton)
      .accessibilityAction { onTap() }
  }
}

/// The bar's sky, temperature, wind and sea, without its capsule: drawn by the bar, and laid out by
/// its copy in the card's presentation, where `slots` marks where its parts fly from.
struct MapWeatherBarLabel: View {
  let content: MapWeatherContent
  var slots: MapWeatherSlots?
  @ScaledMetric(relativeTo: .subheadline) private var size = MapWeatherBarLabel.size

  /// The bar's text size, before Dynamic Type scales it.
  static let size: CGFloat = 15

  var body: some View {
    HStack(spacing: 6) {
      if MapWeatherSky.shows(content) {
        MapWeatherSky(content: content, size: size)
          .mapWeatherSlot(.sky, slots)
      }
      if MapWeatherWind.shows(content) {
        MapWeatherWind(content: content, size: size)
          .mapWeatherSlot(.wind, slots)
          .padding(.leading, 4)
      }
      if MapWeatherSea.shows(content) {
        MapWeatherSea(content: content, size: size)
          .mapWeatherSlot(.sea, slots)
          .padding(.leading, 4)
      }
    }
  }
}

extension View {
  /// The weather bar's capsule, as tall as the map's round buttons beside it.
  func mapWeatherBarChrome() -> some View {
    mapWeatherBarLayout()
      .contentShape(Capsule())
      .pickerControl(in: Capsule())
  }

  /// The bar's type and size without its glass.
  func mapWeatherBarLayout() -> some View {
    font(.subheadline)
      .monospacedDigit()
      .lineLimit(1)
      .fixedSize()
      .padding(.horizontal, 14)
      .frame(height: MapRoundButtonStyle.side)
  }
}

#Preview {
  NavigationStack {
    Color.teal.opacity(0.3)
      .ignoresSafeArea()
      .toolbar {
        ToolbarItem(placement: .principal) {
          MapWeatherBar(content: .sample, onTap: {})
        }
      }
  }
}
