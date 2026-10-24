import OpenDivingKit
import SwiftUI

/// A note's badge and sentence, toned as the web tones it: only a loss reads as a warning.
struct ImportNoteLine: View {
  let badge: String?
  let tone: ImportNoteTone
  let text: String
  var places: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 1) {
      HStack(alignment: .firstTextBaseline, spacing: 6) {
        if let badge {
          Text(badge)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 4)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(color.opacity(0.4)))
        }
        Text(text).font(.footnote)
      }
      .foregroundStyle(color)
      if let places {
        Text(places).font(.caption2).foregroundStyle(.secondary)
      }
    }
  }

  private var color: Color {
    switch tone {
    case .warning: .orange
    case .neutral: .primary
    case .muted: .secondary
    }
  }
}

#Preview {
  List {
    ImportNoteLine(badge: "Dropped", tone: .warning, text: "A tank pressure was dropped.")
    ImportNoteLine(badge: nil, tone: .neutral, text: "1 tag is new.", places: "3 times")
  }
}
