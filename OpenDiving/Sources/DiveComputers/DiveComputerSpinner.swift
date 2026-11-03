import OpenDivingKit
import SwiftUI

/// The download screen's spinner, drawn as the system's, in eight spokes. Each frame is computed
/// from the time, so no state of the List row it sits in can leave it stopped, as one can leave a
/// `ProgressView`, whose UIKit indicator then hides itself and keeps its space.
struct DiveComputerSpinner: View {
  private static let spokes = 8

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1 / Double(Self.spokes))) { timeline in
      let step = Int(timeline.date.timeIntervalSinceReferenceDate * Double(Self.spokes))
      ZStack {
        ForEach(0..<Self.spokes, id: \.self) { spoke in
          Capsule()
            .frame(width: 2.5, height: 6)
            .offset(y: -6)
            .rotationEffect(.degrees(Double(spoke) * 360 / Double(Self.spokes)))
            .opacity(Self.opacity(spoke: spoke, step: step))
        }
      }
      .foregroundStyle(.secondary)
    }
    .frame(width: 20, height: 20)
    .accessibilityHidden(true)
  }

  /// The leading spoke is opaque, and each one behind it fainter.
  private static func opacity(spoke: Int, step: Int) -> Double {
    let behind = ((step - spoke) % spokes + spokes) % spokes
    return 1 - Double(behind) * 0.1
  }
}

#Preview {
  List {
    HStack(spacing: 8) {
      DiveComputerSpinner()
      Text(DiveComputerText.reading)
    }
  }
}
