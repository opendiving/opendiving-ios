import MapLibre

/// A map that says when it is laid out, the first time being when it has a size to cover.
final class LaidOutMapView: MLNMapView {
  var onLayout: (() -> Void)?

  override func layoutSubviews() {
    super.layoutSubviews()
    onLayout?()
  }
}
