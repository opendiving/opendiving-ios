import OpenDivingKit
import SwiftUI
import UIKit

/// A page head's or a card's map: the instance's own tiles for its places, the web's, with the
/// pins drawn over them and fitted between the `coveredTop` points a bar covers and the
/// `coveredBottom` points the details cover, below an `overflowTop` that only a pull-down
/// shows. Nothing is drawn until every tile is to hand, nor where the tiles cannot be had, so
/// whatever is behind shows; nothing is asked for while the map is scrolled out of sight.
struct MapBackdropView: View {
  let points: [MapPoint]
  let fixes: [MapPoint]
  var overflowTop: CGFloat = 0
  var coveredTop: CGFloat = 0
  let coveredBottom: CGFloat
  /// Draw a record with no place too, as the whole world.
  var worldWhenEmpty = false
  /// Where a page head carries the credit on its details: the credit the instance's tiles owe,
  /// whether or not a set is on screen yet. Without it the map carries its own, over its top
  /// corner, as a card's does.
  var credit: Binding<String?>?

  @Environment(Session.self) private var session
  @Environment(\.colorScheme) private var colorScheme
  @State private var model: MapBackdropModel?
  @State private var size = CGSize.zero
  @State private var images: [MapTileAddress: UIImage] = [:]
  @State private var isOnScreen = false
  @State private var chipBottom: CGFloat = 0

  /// The credit chip's inset from the map's corner.
  private static let chipInset: CGFloat = 4

  private var layout: MapBackdropLayout? {
    MapBackdropLayout(
      points: points, fixes: fixes, theme: colorScheme == .dark ? .dark : .light,
      width: size.width, height: size.height, overflowTop: overflowTop,
      coveredTop: max(coveredTop, chipBottom), coveredBottom: coveredBottom,
      worldWhenEmpty: worldWhenEmpty)
  }

  var body: some View {
    Color.clear
      .onGeometryChange(for: CGSize.self) {
        $0.size
      } action: {
        size = $0
      }
      .overlay {
        if let shown = model?.shown, images.count == shown.images.count {
          map(shown.layout)
            .transition(.opacity)
        }
      }
      .animation(.easeOut(duration: 0.3), value: model?.shown != nil)
      .clipped()
      .overlay(alignment: .topLeading) {
        if credit == nil, let named = model?.credit {
          creditChip(named)
        }
      }
      .onScrollVisibilityChange(threshold: 0.01) { isOnScreen = $0 }
      .task(id: Shown(layout: layout, isOnScreen: isOnScreen)) {
        guard isOnScreen else { return }
        if model == nil { model = MapBackdropModel(session: session) }
        await model?.show(layout)
      }
      .onChange(of: model?.shown, initial: true) { _, shown in
        images = (shown?.images ?? [:]).compactMapValues(UIImage.init(data:))
      }
      .onChange(of: model?.credit, initial: true) { _, named in
        credit?.wrappedValue = named
      }
  }

  private struct Shown: Hashable {
    let layout: MapBackdropLayout?
    let isOnScreen: Bool
  }

  private func map(_ layout: MapBackdropLayout) -> some View {
    ZStack(alignment: .topLeading) {
      ForEach(Array(layout.tiles.enumerated()), id: \.offset) { _, tile in
        if let image = images[tile.address] {
          Image(uiImage: image)
            .resizable()
            .frame(width: layout.tileSize, height: layout.tileSize)
            .position(x: tile.x + layout.tileSize / 2, y: tile.y + layout.tileSize / 2)
        }
      }
      ForEach(Array(layout.pins.enumerated()), id: \.offset) { _, pin in
        MapMarker(isFix: pin.isFix)
          .position(x: pin.x, y: pin.y)
      }
    }
    .frame(width: size.width, height: size.height, alignment: .topLeading)
  }

  /// Laid out but unseen until the map shows, as the web's is, since where the pins' band
  /// starts depends on its height.
  private func creditChip(_ named: String) -> some View {
    MapCredit(credit: named)
      .opacity(model?.shown == nil ? 0 : 0.75)
      .padding([.top, .leading], Self.chipInset)
      .onGeometryChange(for: CGFloat.self) {
        $0.size.height
      } action: {
        chipBottom = $0
      }
      .accessibilityHidden(model?.shown == nil)
  }
}

#Preview {
  @Previewable @State var credit: String?
  ScrollView {
    MapBackdropView(
      points: [MapPoint(name: "Blue Hole", latitude: 28.5722, longitude: 34.5372)],
      fixes: [MapPoint(name: "Exit", latitude: 28.5735, longitude: 34.5361)], coveredBottom: 120,
      credit: $credit
    )
    .frame(height: 280)
    .background(Color(.secondarySystemBackground))
  }
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
