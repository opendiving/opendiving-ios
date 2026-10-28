/// A ``ProfileChart`` with a selection applied: each shown line on its scale, the depth
/// plot's labelled edges and the rows under it.
public struct ProfileChartLayout: Hashable, Sendable {
  public var placement: ProfileScalePlacement
  /// The shown lines, in the chart's order.
  public var shown: [ProfilePlottedLine]
  public var units: UnitSystem
  public var duration: Int

  init(chart: ProfileChart, visible: Set<ProfileChannel>) {
    units = chart.units
    duration = chart.duration
    let placement = ProfileScalePlacement(shown: visible)
    self.placement = placement
    let lines = chart.lines.filter { visible.contains($0.channel) }

    // A row's scale is fitted to the channels shown on it, unlike depth's: a hidden
    // gradient factor in the thousands would otherwise flatten a CNS of 23 %.
    var rows: [ProfileAxis: AxisDomain] = [:]
    for axis in placement.panels {
      rows[axis] = axis.domain(lines.filter { $0.channel.axis == axis }.flatMap(\.drawnValues))
    }
    // Numbered under the right edge's labels, so fitted to that edge's gridline count —
    // across every cylinder, as pressure always is.
    var underRight: AxisDomain?
    if let channel = placement.underRight,
      let right = chart.lines.first(where: { $0.channel == placement.right })?.ownDomain
    {
      underRight = AxisDomain.aligned(
        chart.lines.filter { $0.channel == channel }.flatMap(\.series.values),
        steps: right.stepCount)
    }

    shown = lines.compactMap { line in
      let domain =
        (line.channel == placement.underRight ? underRight : nil) ?? line.ownDomain
        ?? rows[line.channel.axis]
      guard let domain else { return nil }
      return ProfilePlottedLine(
        line: line, domain: domain,
        panelIndex: placement.panels.firstIndex(of: line.channel.axis))
    }
  }

  /// The line labelling a scale: any cylinder answers for pressure, all sharing one domain.
  public func plotted(_ channel: ProfileChannel?) -> ProfilePlottedLine? {
    guard let channel else { return nil }
    return shown.first { $0.line.channel == channel }
  }

  /// The depth plot's left-hand numbers, which its gridlines follow.
  public var leftLabels: [ProfileAxisLabel] {
    plotted(placement.left)?.tickLabels ?? []
  }

  /// The right-hand numbers, each with the third scale's beneath it where there is one.
  public var rightLabels: [ProfileAxisLabel] {
    guard var labels = plotted(placement.right)?.tickLabels else { return [] }
    if let under = plotted(placement.underRight)?.tickLabels, under.count == labels.count {
      for index in labels.indices { labels[index].under = under[index].text }
    }
    return labels
  }

  /// One row per panel axis: its two rules and their numbers, the top one carrying the
  /// unit. Two rather than every tick, which in a row this short collide.
  public var panelRows: [ProfilePanelRow] {
    placement.panels.enumerated().compactMap { index, axis in
      guard let row = shown.first(where: { $0.panelIndex == index }) else { return nil }
      let ticks = row.domain.ticks
      guard let top = ticks.last, let bottom = ticks.first else { return nil }
      return ProfilePanelRow(
        axis: axis, index: index,
        top: NumberText.plain(top) + axis.unitSuffix(units),
        bottom: NumberText.plain(bottom))
    }
  }

  /// One row per shown line at the instant `at`, each quoting the nearest drawn sample in
  /// reach — never an interpolation — and keeping its row with no sample where the line
  /// recorded nothing near enough. With no instant every row is empty.
  public func readouts(at: Double?) -> [ProfileReadout] {
    shown.map { plotted in
      let line = plotted.line
      var sample: ProfileReadout.Sample?
      if let at,
        let index = DiveProfileMath.drawnSampleIndex(
          line.series.times, at: at, tolerance: line.runs.readoutTolerance,
          drawn: line.runs.drawn)
      {
        let value = line.series.values[index]
        sample = ProfileReadout.Sample(
          time: line.series.times[index], value: value,
          text: line.series.display.format(value), offset: plotted.offset(value),
          offScale: value < plotted.domain.min || value > plotted.domain.max)
      }
      return ProfileReadout(
        id: line.id, label: line.label, channel: line.channel, panelIndex: plotted.panelIndex,
        sample: sample)
    }
  }

  /// What the chart shows, in a sentence for VoiceOver: the span, each shown channel's
  /// telling extreme at its own decimals, and the markers when they are on.
  public func summary(events: [ProfileChartEvent]) -> String {
    var parts = [
      "Dive profile over "
        + DiveProfileMath.formatElapsedSpoken(milliseconds: Double(duration))
    ]
    for channel in ProfileChannel.allCases {
      let lines = shown.filter { $0.line.channel == channel }.map(\.line)
      let values = lines.flatMap(\.drawnValues)
      guard let lowest = values.min(), let highest = values.max(),
        let decimals = lines.first?.series.display.decimals
      else { continue }
      let low = NumberText.fixed(lowest, decimals: decimals)
      let high = NumberText.fixed(highest, decimals: decimals)
      let word = channel.word(units)
      let phrase =
        switch channel {
        case .depth: "maximum depth \(high) \(word)"
        case .ceiling: "deco ceiling to \(high) \(word)"
        case .temperature: "temperature \(low) to \(high) \(word)"
        case .pressure: "tank pressure \(high) down to \(low) \(word)"
        case .heartRate: "heart rate \(low) to \(high) \(word)"
        case .ndl: "no-decompression time down to \(low) \(word)"
        case .tts: "time to surface up to \(high) \(word)"
        case .ppo2: "oxygen partial pressure up to \(high) \(word)"
        case .cns: "CNS to \(high) \(word)"
        case .gradientFactor: "gradient factor at depth to \(high) \(word)"
        case .surfaceGradientFactor: "surface gradient factor to \(high) \(word)"
        }
      parts.append(phrase)
    }
    if !events.isEmpty {
      var named = events.sorted { $0.time < $1.time }.prefix(Self.describedEvents).map {
        $0.text + " at "
          + DiveProfileMath.formatElapsedSpoken(milliseconds: Double($0.time))
      }
      if events.count > named.count { named.append("and \(events.count - named.count) more") }
      parts.append("markers: " + named.joined(separator: ", "))
    }
    return parts.joined(separator: ", ") + "."
  }

  static let describedEvents = 8
}

/// A shown line on its scale.
public struct ProfilePlottedLine: Hashable, Sendable, Identifiable {
  public var line: ProfileChartLine
  public var domain: AxisDomain
  /// The row under the depth plot the line is drawn in, or nil for the depth plot.
  public var panelIndex: Int?

  public var id: String { line.id }

  /// How far down its band `value` sits, from 0 at the top edge to 1 at the bottom:
  /// depth and the ceiling grow downward from the surface, everything else upward.
  public func offset(_ value: Double) -> Double {
    let fraction = domain.fraction(value)
    return line.channel.isInverted ? fraction : 1 - fraction
  }

  /// The line's runs as points down its band. A panel row clips its lines to the row, so
  /// a reading past the bound is drawn crossing the row's top rule and gone, rather than
  /// flattened along it as though it read 200 % or run on across the depth plot.
  public var paths: [[ProfilePoint]] {
    line.runs.segments.flatMap { segment -> [[ProfilePoint]] in
      let points = segment.map {
        ProfilePoint(time: Double(line.series.times[$0]), offset: offset(line.series.values[$0]))
      }
      return panelIndex == nil ? [points] : Self.clip(points)
    }
  }

  /// The domain's gridline values, each with its number.
  var tickLabels: [ProfileAxisLabel] {
    domain.ticks.map { ProfileAxisLabel(position: offset($0), text: NumberText.plain($0)) }
  }

  /// A polyline cut to the band `0...1`, a segment that crosses an edge ending on it.
  static func clip(_ points: [ProfilePoint]) -> [[ProfilePoint]] {
    guard points.count > 1 else {
      return points.allSatisfy { (0...1).contains($0.offset) } ? [points] : []
    }
    var runs: [[ProfilePoint]] = []
    var current: [ProfilePoint] = []
    func flush() {
      if !current.isEmpty { runs.append(current) }
      current = []
    }
    for (from, to) in zip(points, points.dropFirst()) {
      guard let (start, end, fromInside, toInside) = clipSegment(from, to) else {
        flush()
        continue
      }
      if !fromInside || current.isEmpty {
        flush()
        current = [start]
      }
      current.append(end)
      if !toInside { flush() }
    }
    flush()
    return runs
  }

  /// The part of one segment inside the band, and whether it keeps each end.
  private static func clipSegment(_ from: ProfilePoint, _ to: ProfilePoint)
    -> (ProfilePoint, ProfilePoint, Bool, Bool)?
  {
    let rise = to.offset - from.offset
    if rise == 0 {
      return (0...1).contains(from.offset) ? (from, to, true, true) : nil
    }
    let atTop = (0 - from.offset) / rise
    let atBottom = (1 - from.offset) / rise
    let enter = max(0, min(atTop, atBottom))
    let leave = min(1, max(atTop, atBottom))
    guard enter <= leave else { return nil }
    func point(_ t: Double) -> ProfilePoint {
      if t == 0 { return from }
      if t == 1 { return to }
      return ProfilePoint(
        time: from.time + (to.time - from.time) * t,
        offset: min(1, max(0, from.offset + rise * t)))
    }
    return (point(enter), point(leave), enter == 0, leave == 1)
  }
}

/// A row's scale under the depth plot: its two rules' numbers, the top one with the unit.
public struct ProfilePanelRow: Hashable, Sendable {
  public var axis: ProfileAxis
  /// Its position among the rows, from the top.
  public var index: Int
  public var top: String
  public var bottom: String
}

/// What a shown line reads at the crosshair.
public struct ProfileReadout: Hashable, Sendable, Identifiable {
  public struct Sample: Hashable, Sendable {
    /// The sample's own instant, where its dot goes.
    public var time: Int
    public var value: Double
    /// `21.6°C`, `38 bar`, `18.3 m`.
    public var text: String
    /// How far down its band the dot sits.
    public var offset: Double
    /// The reading is past its row's bound, so the curve has left the row and there is no
    /// honest place for a dot; the readout still quotes it.
    public var offScale: Bool
  }

  public var id: String
  public var label: String
  public var channel: ProfileChannel
  public var panelIndex: Int?
  /// Nil where the line recorded nothing near enough to quote: the row stays, with a dash.
  public var sample: Sample?
}
