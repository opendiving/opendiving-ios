import OpenDivingKit
import SwiftUI

extension View {
  /// The floating button over a download the diver left running: in a corner of this view, which
  /// the diver drags it between, and opening the download's screen in a sheet.
  func diveComputerDownloadButton() -> some View {
    modifier(DiveComputerDownloadOverlay())
  }
}

private struct DiveComputerDownloadOverlay: ViewModifier {
  @Environment(DiveComputerDownloads.self) private var downloads
  @State private var drag = CGSize.zero
  @State private var showsDownload = false

  /// The button's diameter, and its distance from the edges of the safe area.
  private static let size: CGFloat = 56
  private static let margin: CGFloat = 16
  /// The navigation bar's height, which a tab's safe area does not include at its top.
  private static let navigationBar: CGFloat = 52

  func body(content: Content) -> some View {
    content
      .overlay {
        if let button = downloads.button {
          GeometryReader { proxy in
            let place = { (corner: ScreenCorner) in Self.place(corner, in: proxy.size) }
            let rest = place(downloads.corner)
            // The drag is read globally: the button moves under the finger, and its own
            // coordinates with it.
            DiveComputerDownloadButton(content: button) { showsDownload = true }
              .highPriorityGesture(
                DragGesture(coordinateSpace: .global)
                  .onChanged { drag = $0.translation }
                  .onEnded { value in
                    let end = CGPoint(
                      x: rest.x + value.predictedEndTranslation.width,
                      y: rest.y + value.predictedEndTranslation.height)
                    withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
                      downloads.corner = ScreenCorner.nearest(to: end, place: place)
                      drag = .zero
                    }
                  }
              )
              .position(x: rest.x + drag.width, y: rest.y + drag.height)
          }
          .transition(.opacity.combined(with: .scale(scale: 0.6)))
        }
      }
      .animation(.easeOut(duration: 0.2), value: downloads.button == nil)
      .sheet(isPresented: $showsDownload) {
        NavigationStack {
          DiveComputerView()
            .toolbar {
              ToolbarItem(placement: .confirmationAction) {
                Button("Done") { showsDownload = false }
              }
            }
        }
      }
  }

  /// The button's centre resting in `corner` of a safe area `size` big.
  private static func place(_ corner: ScreenCorner, in size: CGSize) -> CGPoint {
    let inset = margin + Self.size / 2
    let top = inset + navigationBar
    let bottom = size.height - inset
    let leading = inset
    let trailing = size.width - inset
    switch corner {
    case .topLeading: return CGPoint(x: leading, y: top)
    case .topTrailing: return CGPoint(x: trailing, y: top)
    case .bottomLeading: return CGPoint(x: leading, y: bottom)
    case .bottomTrailing: return CGPoint(x: trailing, y: bottom)
    }
  }
}
