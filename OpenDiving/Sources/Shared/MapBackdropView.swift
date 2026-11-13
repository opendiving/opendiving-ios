import OpenDivingKit
import SwiftUI
import UIKit

/// A page head's or a card's map: the instance's own tiles for its places, the web's, with the
/// pins drawn over them and fitted between the `coveredTop` points a bar covers and the
/// `coveredBottom` points the details cover, below an `overflowTop` that only a pull-down
/// shows. Nothing is drawn until every tile is to hand, nor where the tiles cannot be had, so
/// whatever is behind shows; nothing is asked for while the map is scrolled well out of sight.
struct MapBackdropView: View {
  let points: [MapPoint]
  let fixes: [MapPoint]
  var overflowTop: CGFloat = 0
  var coveredTop: CGFloat = 0
  let coveredBottom: CGFloat
  /// Draw a record with no place too, as the whole world.
  var worldWhenEmpty = false
  /// Where a page head carries the credit on its details: the credit the instance's tiles owe,
  /// whether or not a set is on screen yet. Without it the map hands ``CardCredit`` up to the
  /// card it sits in.
  var credit: Binding<String?>?

  @Environment(Session.self) private var session
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.displayScale) private var displayScale
  @State private var model: MapBackdropModel?
  @State private var size = CGSize.zero
  @State private var images: [MapTileAddress: UIImage] = [:]
  @State private var isOnScreen = false

  /// Taller than any bar a list scrolls under.
  private static let barAllowance: CGFloat = 120

  private var layout: MapBackdropLayout? {
    MapBackdropLayout(
      points: points, fixes: fixes, theme: colorScheme == .dark ? .dark : .light,
      width: size.width, height: size.height, overflowTop: overflowTop,
      coveredTop: coveredTop, coveredBottom: coveredBottom,
      worldWhenEmpty: worldWhenEmpty, scale: displayScale)
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
      .preference(key: CardCredit.Key.self, value: cardCredit)
      // SwiftUI's visible part of a scroll view stops at its bars and the home indicator, and
      // what scrolls under them is in plain sight.
      .onGeometryChange(for: Bool.self) { proxy in
        guard let clear = proxy.bounds(of: .scrollView) else { return true }
        return clear.insetBy(dx: 0, dy: -Self.barAllowance)
          .intersects(CGRect(origin: .zero, size: proxy.size))
      } action: {
        isOnScreen = $0
      }
      // A view of its own for each map wanted rather than `task(id:)`, which SwiftUI leaves on
      // the old id when a change comes too soon after another ("tried to update multiple times
      // per frame"): a card coming on screen changes it twice, and the window's appearance
      // reaches a screen just pushed right behind them.
      .background {
        Color.clear
          .task {
            guard isOnScreen else { return }
            if model == nil { model = MapBackdropModel(session: session) }
            await model?.show(layout)
          }
          .id(Shown(layout: layout, isOnScreen: isOnScreen))
      }
      .onChange(of: model?.shown, initial: true) { _, shown in
        images = (shown?.images ?? [:]).compactMapValues(UIImage.init(data:))
      }
      .onChange(of: model?.credit, initial: true) { _, named in
        credit?.wrappedValue = named
      }
  }

  /// The credit a map owes, for the card over it to carry: a card's glass would blur anything
  /// drawn with the map, and bare text cannot be read on the map's own labels. Handed up whether
  /// or not a set is on screen, as ``MapBackdropModel/credit`` is kept, and shown only with one.
  struct CardCredit: Equatable {
    let text: String
    let isShown: Bool

    struct Key: PreferenceKey {
      static let defaultValue: CardCredit? = nil

      static func reduce(value: inout CardCredit?, nextValue: () -> CardCredit?) {
        value = value ?? nextValue()
      }
    }
  }

  private var cardCredit: CardCredit? {
    guard credit == nil, let text = model?.credit else { return nil }
    return CardCredit(text: text, isShown: model?.shown != nil)
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
