/// The basemap a tile is drawn in: the screen's appearance.
public enum MapTileTheme: String, Hashable, Sendable {
  case light
  case dark
}

/// One square of the grid in one theme: everything `GET /map-tiles` needs but the language.
public struct MapTileAddress: Hashable, Sendable {
  public let theme: MapTileTheme
  public let z: Int
  public let x: Int
  public let y: Int

  public init(theme: MapTileTheme, z: Int, x: Int, y: Int) {
    self.theme = theme
    self.z = z
    self.x = x
    self.y = y
  }
}
