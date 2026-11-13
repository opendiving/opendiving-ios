import CoreImage
import ImageIO
import OpenDivingKit
import SwiftUI

/// A backdrop photo drawn where `place` puts it in the frame, over a heavily blurred copy of
/// itself filling the frame, its bottom edge — and its top, where the placement cuts it — fading
/// into the copy over ``PhotoPlacement/fade`` points. The species card's and the species page's.
struct PlacedPhotoView: View {
  let data: Data
  let image: UIImage
  let place: (_ photo: CGSize, _ frame: CGSize) -> PhotoPlacement?

  @State private var blurred: UIImage?

  var body: some View {
    GeometryReader { proxy in
      if let backdrop = BlurredPhoto.cached(data) ?? blurred {
        Image(uiImage: backdrop)
          .resizable()
          .scaledToFill()
          .frame(width: proxy.size.width, height: proxy.size.height)
      }
      if let placed = place(image.size, proxy.size) {
        Image(uiImage: image)
          .resizable()
          .frame(width: placed.width, height: placed.height)
          .mask { fadeMask(placed) }
          .position(x: placed.x + placed.width / 2, y: placed.y + placed.height / 2)
      }
    }
    .clipped()
    .accessibilityHidden(true)
    .task(id: data) {
      if BlurredPhoto.cached(data) == nil { blurred = await BlurredPhoto.make(data) }
    }
  }

  private func fadeMask(_ placed: PhotoPlacement) -> LinearGradient {
    let height = max(placed.height, 1)
    let fade = min(PhotoPlacement.fade / height, 0.5)
    var stops = [
      Gradient.Stop(color: .black, location: 1 - fade), .init(color: .clear, location: 1),
    ]
    if let cutTop = placed.cutTop {
      let cut = min(max((cutTop - placed.y) / height, 0), 1 - 2 * fade)
      stops.insert(
        contentsOf: [
          .init(color: .clear, location: cut), .init(color: .black, location: cut + fade),
        ],
        at: 0)
    }
    return LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom)
  }
}

/// A photo blurred once, small, and kept: a live blur over each card of a scrolling list costs a
/// frame, and a copy this blurred loses nothing by being drawn up from a few dozen pixels.
nonisolated private enum BlurredPhoto {
  /// The blur, as a share of the photo's width: the 28 points over a card's 361.
  private static let radius = 28.0 / 361
  private static let pixels = 64

  // NSCache is thread-safe, though not marked Sendable.
  nonisolated(unsafe) private static let cache: NSCache<NSData, UIImage> = {
    let cache = NSCache<NSData, UIImage>()
    cache.countLimit = 500
    return cache
  }()
  private static let context = CIContext()

  static func cached(_ data: Data) -> UIImage? {
    cache.object(forKey: data as NSData)
  }

  static func make(_ data: Data) async -> UIImage? {
    await Task.detached(priority: .userInitiated) { () -> UIImage? in
      guard let source = CGImageSourceCreateWithData(data as CFData, nil),
        let thumbnail = CGImageSourceCreateThumbnailAtIndex(
          source, 0,
          [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: pixels,
          ] as CFDictionary)
      else { return nil }
      let input = CIImage(cgImage: thumbnail)
      let output = input.clampedToExtent()
        .applyingGaussianBlur(sigma: radius * Double(thumbnail.width))
        .cropped(to: input.extent)
      guard let blurred = context.createCGImage(output, from: input.extent) else { return nil }
      let image = UIImage(cgImage: blurred)
      cache.setObject(image, forKey: data as NSData)
      return image
    }.value
  }
}

#Preview {
  ScrollView {
    VStack(spacing: 12) {
      ForEach(PlacedPhotoView.previewPhotos, id: \.self) { data in
        if let image = UIImage(data: data) {
          PlacedPhotoView(data: data, image: image) { photo, frame in
            .card(
              photoWidth: photo.width, photoHeight: photo.height, width: frame.width,
              band: CardBackdropFrame.band)
          }
          .frame(height: 250)
          .overlay(alignment: .bottom) {
            Color.clear.frame(height: 118).background(.thinMaterial)
          }
          .clipShape(.formSection)
        }
      }
    }
    .padding()
  }
}

extension PlacedPhotoView {
  /// A landscape, a portrait and a panorama, striped and ringed at the centre so a preview shows
  /// where a photo's middle and edges land.
  static let previewPhotos: [Data] = [
    CGSize(width: 1500, height: 1000), CGSize(width: 800, height: 1200),
    CGSize(width: 3000, height: 1000),
  ].compactMap { size in
    UIGraphicsImageRenderer(size: size).image { context in
      for band in 0..<10 {
        UIColor(hue: Double(band) / 10, saturation: 0.6, brightness: 0.9, alpha: 1).setFill()
        context.fill(
          CGRect(
            x: 0, y: size.height * Double(band) / 10, width: size.width,
            height: size.height / 10))
      }
      let side = min(size.width, size.height) / 3
      UIColor.black.setStroke()
      let ring = UIBezierPath(
        ovalIn: CGRect(
          x: (size.width - side) / 2, y: (size.height - side) / 2, width: side, height: side))
      ring.lineWidth = side / 10
      ring.stroke()
    }.jpegData(compressionQuality: 0.8)
  }
}
