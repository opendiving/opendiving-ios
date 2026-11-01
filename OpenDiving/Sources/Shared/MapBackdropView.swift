import OpenDivingKit
import SwiftUI
import UIKit

/// A page head's map: the instance's own tiles for its places, the web's, with the pins drawn
/// over them and fitted above the `coveredBottom` points the details cover. Nothing is drawn
/// until every tile is to hand, nor where the tiles cannot be had, so the band behind shows.
struct MapBackdropView: View {
  let points: [MapPoint]
  let fixes: [MapPoint]
  let coveredBottom: CGFloat
  /// The credit the map on screen owes; nil while none is on screen.
  @Binding var credit: String?

  @Environment(Session.self) private var session
  @Environment(\.colorScheme) private var colorScheme
  @State private var model: MapBackdropModel?
  @State private var size = CGSize.zero
  @State private var images: [MapTileAddress: UIImage] = [:]

  /// #FF7F50, the brand's coral, which the web's pins are drawn in for reading on both themes.
  private static let coral = Color(red: 1, green: 127 / 255, blue: 80 / 255)

  private var layout: MapBackdropLayout? {
    MapBackdropLayout(
      points: points, fixes: fixes, theme: colorScheme == .dark ? .dark : .light,
      width: size.width, height: size.height, coveredBottom: coveredBottom)
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
      .task(id: layout) {
        if model == nil { model = MapBackdropModel(session: session) }
        await model?.show(layout)
      }
      .onChange(of: model?.shown, initial: true) { _, shown in
        images = (shown?.images ?? [:]).compactMapValues(UIImage.init(data:))
        credit = shown?.credit
      }
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
        marker(isFix: pin.isFix)
          .position(x: pin.x, y: pin.y)
      }
    }
    .frame(width: size.width, height: size.height, alignment: .topLeading)
  }

  /// A place in coral ringed in the page's colour, and a fix the same two colours inverted, as
  /// the web draws them: one legend, two claims.
  private func marker(isFix: Bool) -> some View {
    Circle()
      .fill(isFix ? Color(.systemBackground).opacity(0.8) : Self.coral)
      .strokeBorder(isFix ? Self.coral : Color(.systemBackground), lineWidth: 2)
      .frame(width: 12, height: 12)
      .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
  }
}

#Preview {
  @Previewable @State var credit: String?
  MapBackdropView(
    points: [MapPoint(name: "Blue Hole", latitude: 28.5722, longitude: 34.5372)],
    fixes: [MapPoint(name: "Exit", latitude: 28.5735, longitude: 34.5361)], coveredBottom: 120,
    credit: $credit
  )
  .frame(height: 280)
  .background(Color(.secondarySystemBackground))
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
