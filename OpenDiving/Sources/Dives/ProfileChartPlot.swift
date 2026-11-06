import Charts
import OpenDivingKit
import SwiftUI

/// The chart itself: the depth plot with its two edges, the rows under it on
/// one time axis, the markers on the depth plot's baseline, and a drag scrubber. Every
/// number on it is a Kit string drawn verbatim — never Swift Charts' own axis labels, which
/// format in the phone's region.
struct ProfileChartPlot: View {
  let chart: ProfileChart
  @Binding var hidden: Set<ProfileChannel>
  @Binding var markersHidden: Bool

  @State private var selected: Double?
  @State private var plotFrame = CGRect.zero
  /// The stretch on screen, nil until a first pinch. The card's load between recordings takes
  /// this view away, so a new recording starts whole.
  @State private var zoom: ProfileTimeWindow?
  /// Two fingers on the plot: the window they landed on, and how far across it.
  @State private var fingers: (window: ProfileTimeWindow, from: Double)?

  var body: some View {
    let layout = chart.layout(hiding: hidden)
    let markersShown = !markersHidden && !chart.events.isEmpty
    let bands = Bands(panelCount: layout.placement.panels.count)
    // Two fingers move the plot and take the crosshair off it, though the first to land has
    // already started the readout.
    let at =
      fingers == nil ? selected.map { min(Double(window.end), max(Double(window.start), $0)) } : nil

    VStack(alignment: .trailing, spacing: 4) {
      HStack(spacing: 0) {
        if isZoomed {
          Button {
            zoom = nil
          } label: {
            Image(.zoomOut)
              .frame(minWidth: 44, minHeight: 44)
          }
          .accessibilityLabel("Zoom out")
        }
        ProfileChannelMenu(chart: chart, hidden: $hidden, markersHidden: $markersHidden)
      }
      plot(layout: layout, bands: bands, markersShown: markersShown, at: at)
        .frame(height: bands.total + 28)
        .overlay {
          if layout.shown.isEmpty && !markersShown {
            Text("Every channel is hidden. Pick one from the menu to plot it.")
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
              .allowsHitTesting(false)
          }
        }
        .overlay(
          alignment: at.map { $0 < Double(window.start + window.end) / 2 } ?? true
            ? .topTrailing : .topLeading
        ) {
          if let at {
            ProfileReadoutCard(
              elapsed: DiveProfileMath.formatElapsed(milliseconds: at),
              readouts: layout.readouts(at: at),
              event: markersShown ? chart.event(near: at, within: eventReach) : nil
            )
            .padding(.horizontal, 44)
            .allowsHitTesting(false)
          }
        }
    }
  }

  // MARK: The plot

  private func plot(layout: ProfileChartLayout, bands: Bands, markersShown: Bool, at: Double?)
    -> some View
  {
    let ticks = chart.timeTicks(plotWidth: plotWidth, window: window)
    let left = layout.leftLabels.map { label in
      AxisLabel(y: bands.y(label.position, panel: nil), text: label.text, under: nil)
    }
    let rows = layout.panelRows.flatMap { row in
      [
        AxisLabel(y: bands.top(row.index), text: row.top, under: nil),
        AxisLabel(y: bands.top(row.index) - Bands.panelHeight, text: row.bottom, under: nil),
      ]
    }
    let right = layout.rightLabels.map { label in
      AxisLabel(y: bands.y(label.position, panel: nil), text: label.text, under: label.under)
    }
    let leftColor = layout.placement.left?.color ?? .secondary
    let rightColor = layout.placement.right?.color ?? .secondary
    let underColor = layout.placement.underRight?.color ?? .secondary
    let dots = (at.map(layout.readouts(at:)) ?? []).compactMap { readout -> Dot? in
      guard let sample = readout.sample, !sample.offScale,
        (window.start...window.end).contains(sample.time)
      else { return nil }
      return Dot(
        id: readout.id, time: Double(sample.time),
        y: bands.y(sample.offset, panel: readout.panelIndex),
        color: readout.channel.color)
    }

    return Chart {
      ForEach(fills(layout, bands)) { fill in
        AreaPlot(
          fill.points, x: .value("Time", \.time), yStart: .value("Surface", \.surface),
          yEnd: .value("Value", \.y), series: .value("Run", \.run)
        )
        .foregroundStyle(fill.color)
      }

      ForEach(layout.shown.filter { $0.line.channel != .depth }) { plotted in
        LinePlot(
          points(plotted, bands), x: .value("Time", \.time), y: .value("Value", \.y),
          series: .value("Run", \.run)
        )
        .foregroundStyle(plotted.line.channel.color)
        .lineStyle(
          StrokeStyle(
            lineWidth: 1.5, lineCap: .round, lineJoin: .round,
            dash: plotted.line.channel.isDashed ? [5, 3] : []))
      }

      if markersShown {
        ForEach(Array(chart.events.enumerated()), id: \.offset) { _, event in
          RuleMark(
            x: .value("Time", Double(event.time)), yStart: .value("Baseline", bands.plotBottom),
            yEnd: .value("Tick", bands.plotBottom + Bands.eventTick)
          )
          .foregroundStyle(event.color)
          .lineStyle(StrokeStyle(lineWidth: 1))
          PointMark(
            x: .value("Time", Double(event.time)),
            y: .value("Glyph", bands.plotBottom + Bands.eventTick + Bands.eventGlyph)
          )
          .symbol(event.symbol)
          .symbolSize(40)
          .foregroundStyle(event.color)
        }
      }

      if let at {
        RuleMark(
          x: .value("Time", at), yStart: .value("Foot", 0.0), yEnd: .value("Top", bands.total)
        )
        .foregroundStyle(Color(.secondaryLabel))
        .lineStyle(StrokeStyle(lineWidth: 1))
        ForEach(dots) { dot in
          PointMark(x: .value("Time", dot.time), y: .value("Value", dot.y))
            .symbolSize(50)
            .foregroundStyle(dot.color)
        }
      }
    }
    .chartXScale(domain: Double(window.start)...Double(max(window.end, 1)))
    .chartYScale(domain: 0...bands.total)
    .chartXAxis {
      AxisMarks(values: ticks.map(\.position)) { value in
        AxisTick()
        AxisValueLabel(anchor: .top, collisionResolution: .disabled) {
          Text(ticks[value.index].text)
        }
      }
    }
    .chartYAxis {
      AxisMarks(position: .leading, values: left.map(\.y)) { value in
        AxisGridLine()
        AxisValueLabel(collisionResolution: .disabled) {
          Text(left[value.index].text).foregroundStyle(leftColor)
        }
      }
      AxisMarks(position: .leading, values: rows.map(\.y)) { value in
        AxisGridLine()
        AxisValueLabel(collisionResolution: .disabled) {
          Text(rows[value.index].text).font(.caption2).foregroundStyle(.secondary)
        }
      }
      AxisMarks(position: .trailing, values: right.map(\.y)) { value in
        AxisValueLabel(collisionResolution: .disabled) {
          VStack(alignment: .leading, spacing: 0) {
            Text(right[value.index].text).foregroundStyle(rightColor)
            if let under = right[value.index].under {
              Text(under).foregroundStyle(underColor)
            }
          }
        }
      }
    }
    .chartXSelection(value: $selected)
    // Zoomed, the curves run on past both ends of the plot. Whole, nothing does, and a dot at
    // the plot's edge keeps its outer half. An inset rather than a condition, so the plot
    // keeps its identity as a pinch leaves the whole dive.
    .chartPlotStyle { $0.clipShape(Rectangle().inset(by: isZoomed ? 0 : -8)) }
    .chartBackground { proxy in
      GeometryReader { geometry in
        let frame = proxy.plotFrame.map { geometry[$0] } ?? .zero
        Color.clear.onChange(of: frame, initial: true) { plotFrame = frame }
      }
    }
    .gesture(twoFingers(.pinch))
    .gesture(twoFingers(.slide, isEnabled: isZoomed))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(layout.summary(events: markersShown ? chart.events : []))
  }

  /// The water column under the depth curve and the band above the ceiling, each filled
  /// from the surface per run, so neither spans a stretch nothing was recorded in.
  private func fills(_ layout: ProfileChartLayout, _ bands: Bands) -> [Fill] {
    [(ProfileChannel.depth, 0.15), (.ceiling, 0.25)].compactMap { channel, opacity in
      layout.plotted(channel).map { plotted in
        Fill(
          id: channel.rawValue, points: points(plotted, bands),
          color: channel.color.opacity(opacity))
      }
    }
  }

  private func points(_ plotted: ProfilePlottedLine, _ bands: Bands) -> [PlotPoint] {
    let surface = bands.top(plotted.panelIndex)
    // Series names are global to a chart, so each run is named after its line as well:
    // a bare run index would join one channel's run to another's and draw both in one style.
    return plotted.paths(in: window, plotWidth: plotWidth).enumerated().flatMap { run, path in
      path.map {
        PlotPoint(
          time: $0.time, y: bands.y($0.offset, panel: plotted.panelIndex), surface: surface,
          run: "\(plotted.id) \(run)")
      }
    }
  }

  private var plotWidth: Double { max(plotFrame.width, 1) }

  /// How near the finger a marker is named: 8 points, in the axis's milliseconds.
  private var eventReach: Double { Double(window.span) / plotWidth * 8 }

  // MARK: Zoom

  private var window: ProfileTimeWindow { zoom ?? ProfileTimeWindow(duration: chart.duration) }

  private var isZoomed: Bool { window.isZoomed(duration: chart.duration) }

  /// How far across the plot `x` is, in the chart's own points.
  private func fraction(_ x: Double) -> Double {
    min(1, max(0, (x - plotFrame.minX) / plotWidth))
  }

  /// A slide is a pinch that does not spread, so both carry the instant under the fingers.
  private func twoFingers(_ kind: ProfileTwoFingerGesture.Kind, isEnabled: Bool = true)
    -> ProfileTwoFingerGesture
  {
    ProfileTwoFingerGesture(
      kind: kind, isEnabled: isEnabled,
      began: { fingers = (window, fraction($0)) },
      changed: { x, scale in
        guard let fingers else { return }
        zoom = fingers.window.scaled(
          by: scale, from: fingers.from, to: fraction(x), duration: chart.duration)
      },
      ended: {
        fingers = nil
        selected = nil
      })
  }

  // MARK: Geometry

  /// The plot's vertical bands, in chart units with the top at ``total``: the depth plot,
  /// then each row under it with a gap between.
  private struct Bands {
    static let plotHeight = 170.0
    static let panelHeight = 46.0
    static let panelGap = 16.0
    static let eventTick = 9.0
    static let eventGlyph = 6.0

    let panelCount: Int

    var total: Double {
      Self.plotHeight + Double(panelCount) * (Self.panelGap + Self.panelHeight)
    }

    var plotBottom: Double { total - Self.plotHeight }

    func top(_ panel: Int?) -> Double {
      guard let panel else { return total }
      return plotBottom - Self.panelGap - Double(panel) * (Self.panelHeight + Self.panelGap)
    }

    func y(_ offset: Double, panel: Int?) -> Double {
      top(panel) - offset * (panel == nil ? Self.plotHeight : Self.panelHeight)
    }
  }

  private struct PlotPoint {
    let time: Double
    let y: Double
    let surface: Double
    let run: String
  }

  private struct Fill: Identifiable {
    let id: String
    let points: [PlotPoint]
    let color: Color
  }

  private struct Dot: Identifiable {
    let id: String
    let time: Double
    let y: Double
    let color: Color
  }

  private struct AxisLabel {
    let y: Double
    let text: String
    let under: String?
  }
}

extension ProfileChartEvent {
  /// A gas switch in the cylinders' colour; every other marker joins to nothing and is
  /// drawn neutral.
  var color: Color {
    joinsPressure ? ProfileChannel.pressure.color : Color(.secondaryLabel)
  }

  var symbol: BasicChartSymbolShape {
    switch glyph {
    case .diamond: .diamond
    case .triangle: .triangle
    case .circle: .circle
    }
  }

  var systemImage: String {
    switch glyph {
    case .diamond: "diamond.fill"
    case .triangle: "triangle.fill"
    case .circle: "circle.fill"
    }
  }
}

extension ProfileChartPlot {
  /// A forty-minute dive to 18 m with two cylinders, a ceiling, a heart rate and two
  /// markers, for previews.
  static let previewJSON: String = {
    let times = Array(stride(from: 0, through: 2_400_000, by: 20_000))
    let depth = times.map { time -> Int in
      let minutes = Double(time) / 60_000
      return Int(max(0, min(1830, minutes * 600, (40 - minutes) * 300)))
    }
    let temperature = times.map { 2400 - $0 / 20_000 * 2 }
    let pressure = times.map { 2100 - $0 / 20_000 * 10 }
    let ndl = depth.map { $0 > 1500 ? 1200 : 5940 }
    let heartRate = depth.map { 70 + $0 / 60 }
    func series(_ values: [Int], _ times: [Int]) -> String {
      #"{"times":\#(times),"values":\#(values)}"#
    }
    return """
      {"duration":2400000,"depth":\(series(depth, times)),
      "ceiling":\(series([300, 300, 300], [600_000, 620_000, 640_000])),
      "temperature":\(series(temperature, times)),
      "pressures":[{"times":\(times),"values":\(pressure),"gas_number":1}],
      "heart_rate":\(series(heartRate, times)),
      "ndl":\(series(ndl, times)),"tts":null,"ppo2":null,"cns":null,
      "gradient_factor":null,"surface_gradient_factor":null,
      "events":[{"time":4000,"type":"gas_switch","gas_number":1,"label":null},
      {"time":1800000,"type":"safety_stop","gas_number":null,"label":null}],
      "provenance":"file","dive_end_time":2380000}
      """
  }()
}

extension ProfileChart {
  /// ``ProfileChartPlot/previewJSON`` as a chart, for previews.
  static var preview: ProfileChart {
    let profile = try! APICoding.decoder().decode(
      RecordingProfileRead.self, from: Data(ProfileChartPlot.previewJSON.utf8))
    return ProfileChart(profile: profile, units: .metric, cylinders: [1])
  }
}

#Preview {
  @Previewable @State var hidden: Set<ProfileChannel> = []
  @Previewable @State var markersHidden = false
  ProfileChartPlot(chart: .preview, hidden: $hidden, markersHidden: $markersHidden)
    .padding()
}
