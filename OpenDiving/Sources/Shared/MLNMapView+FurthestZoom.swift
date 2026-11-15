import MapLibre

extension MLNMapView {
  /// Sets how far out the map zooms, unless it is already there. MapLibre keeps the floor as a
  /// scale and reads it back through a logarithm, so the floor it returns can be a bit off the one
  /// set; setting it again moves a camera that sits on it, and a move's `regionDidChange` sets it
  /// again, until the stack runs out.
  func zoomOutNoFurtherThan(_ zoom: Double) {
    guard abs(minimumZoomLevel - zoom) > 1e-9 else { return }
    minimumZoomLevel = zoom
  }
}
