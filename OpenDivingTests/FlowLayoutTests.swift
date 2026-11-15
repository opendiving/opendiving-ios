import SwiftUI
import Testing
import UIKit

@testable import OpenDiving

@MainActor
struct FlowLayoutTests {
  private final class Frames {
    var layout = CGRect.null
    var children: [Int: CGRect] = [:]
  }

  /// Placed in bounds exactly as wide as it measured, a line that ends on a separated child keeps
  /// that child: these widths sum a hair wider in one order than the other, which once wrapped
  /// the last child under the height the layout had reported, over whatever came next.
  @Test func placesItsChildrenOnTheLinesItMeasured() throws {
    let scene = try #require(
      UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let window = UIWindow(windowScene: scene)
    window.frame = CGRect(x: 0, y: 0, width: 402, height: 400)
    let frames = Frames()
    window.rootViewController = UIHostingController(
      rootView: VStack(alignment: .leading, spacing: 0) {
        FlowLayout(spacing: 4) {
          Self.block(width: 599 / 3, index: 0, frames: frames)
          Color.clear.frame(width: 3, height: 10).flowSeparator()
          Self.block(width: 383 / 3, index: 1, frames: frames)
        }
        .onGeometryChange(for: CGRect.self) {
          $0.frame(in: .global)
        } action: {
          frames.layout = $0
        }
        Color.clear.frame(height: 10)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading))
    window.makeKeyAndVisible()
    defer { window.isHidden = true }
    window.layoutIfNeeded()

    let first = try #require(frames.children[0])
    let last = try #require(frames.children[1])
    #expect(last.minY == first.minY)
    #expect(last.maxY <= frames.layout.maxY)
  }

  private static func block(width: CGFloat, index: Int, frames: Frames) -> some View {
    Color.clear
      .frame(width: width, height: 10)
      .onGeometryChange(for: CGRect.self) {
        $0.frame(in: .global)
      } action: {
        frames.children[index] = $0
      }
  }
}
