/// One recording's profile as the chart draws it: every series cut at the dive's end and
/// converted to the diver's units, each line's drawable runs, and the markers inside the
/// axis. Built once per recording and unit system; ``layout(hiding:)`` places a selection.
public struct ProfileChart: Hashable, Sendable {
  public var units: UnitSystem
  /// The axis's span in milliseconds: the dive's end where the read carries one, else the
  /// recording's own.
  public var duration: Int
  /// Every line with something to draw, in plot, legend and readout order: depth, the
  /// ceiling, temperature, each cylinder's pressure, then the rows under the depth plot
  /// one by one.
  public var lines: [ProfileChartLine]
  /// The markers inside `[0, duration]`, dropped rather than clamped past either end.
  public var events: [ProfileChartEvent]

  /// `cylinders` is each of the dive's mixtures' gas number in Tanks-card order, which a
  /// pressure line and a gas switch are named by.
  public init(profile: RecordingProfileRead, units: UnitSystem, cylinders: [Int?]) {
    self.units = units
    let end = profile.diveEndTime
    let duration = DiveProfileMath.chartDuration(duration: profile.duration, diveEndTime: end)
    self.duration = duration

    func series(_ channel: ProfileChannel, _ wire: DiveProfileSeries?) -> ChannelSeries? {
      guard let wire else { return nil }
      let cut = DiveProfileMath.cut(
        times: wire.times, values: wire.values, duration: profile.duration, diveEndTime: end)
      return DiveProfileMath.series(channel, times: cut.times, values: cut.values, units: units)
    }
    func line(
      _ id: String, _ series: ChannelSeries, label: String? = nil, domain: AxisDomain? = nil
    ) -> ProfileChartLine {
      let channel = series.display.channel
      return ProfileChartLine(
        id: id, label: label ?? channel.label, series: series,
        runs: DiveProfileMath.runs(times: series.times, channel: channel), ownDomain: domain)
    }

    var lines: [ProfileChartLine] = []
    let depth = series(.depth, profile.depth).map { line("depth", $0) }
    let ceiling = series(.ceiling, profile.ceiling).map { line("ceiling", $0) }
    let vertical = ProfileAxis.depthDomain(
      depth: depth?.drawnValues ?? [], ceiling: ceiling?.drawnValues ?? [])
    for case var entry? in [depth, ceiling] {
      entry.ownDomain = vertical
      lines.append(entry)
    }

    if let temperature = series(.temperature, profile.temperature) {
      lines.append(
        line(
          "temperature", temperature,
          domain: ProfileAxis.temperatureDomain(temperature.values, units: units)))
    }

    let pressures = profile.pressures.compactMap { cylinder -> ChannelSeries? in
      let cut = DiveProfileMath.cut(
        times: cylinder.times, values: cylinder.values, duration: profile.duration,
        diveEndTime: end)
      return DiveProfileMath.series(
        .pressure, times: cut.times, values: cut.values, units: units,
        gasNumber: cylinder.gasNumber)
    }
    let pressureDomain = AxisDomain.nice(pressures.flatMap(\.values))
    for (index, cylinder) in pressures.enumerated() {
      let label =
        pressures.count > 1
        ? ProfileChannel.pressure.label + " ("
          + DiveProfileMath.cylinderName(gasNumber: cylinder.gasNumber ?? 0, cylinders: cylinders)
          + ")"
        : ProfileChannel.pressure.label
      lines.append(line("pressure-\(index)", cylinder, label: label, domain: pressureDomain))
    }

    let rowed: [ProfileChannel: DiveProfileSeries?] = [
      .heartRate: profile.heartRate, .ndl: profile.ndl, .tts: profile.tts, .ppo2: profile.ppo2,
      .cns: profile.cns,
      .surfaceGradientFactor: profile.surfaceGradientFactor,
      .gradientFactor: profile.gradientFactor,
    ]
    for axis in ProfileAxis.panels {
      for channel in axis.channels {
        if let built = series(channel, rowed[channel] ?? nil) {
          lines.append(line(channel.rawValue, built))
        }
      }
    }

    // A line with no drawable run — a ceiling of isolated samples — is not on the chart, so
    // it gets no toggle, no axis, no readout row and no word in the summary either.
    self.lines = lines.filter { !$0.runs.segments.isEmpty }
    events = profile.events
      .filter { $0.time >= 0 && $0.time <= duration }
      .map { ProfileChartEvent($0, cylinders: cylinders) }
  }

  /// The channels this recording both carries and can draw: the legend's entries.
  public var availableChannels: [ProfileChannel] {
    ProfileChannel.allCases.filter { channel in lines.contains { $0.channel == channel } }
  }

  /// False for a recording whose file held no sample to plot.
  public var hasSamples: Bool { !lines.isEmpty }

  /// The marker nearest `at` within `tolerance` milliseconds, a tie going to the earlier,
  /// compared on time rather than on list order.
  public func event(near at: Double, within tolerance: Double) -> ProfileChartEvent? {
    var best: ProfileChartEvent?
    var bestDelta = Double.infinity
    for event in events {
      let delta = abs(Double(event.time) - at)
      guard delta <= tolerance else { continue }
      if best == nil || delta < bestDelta || (delta == bestDelta && event.time < best!.time) {
        best = event
        bestDelta = delta
      }
    }
    return best
  }

  /// The elapsed-time gridlines for a plot `plotWidth` points wide, each with its `M:SS`
  /// label: at most six, and fewer where 44 points a label do not fit.
  public func timeTicks(plotWidth: Double) -> [ProfileAxisLabel] {
    let target = Swift.min(
      DiveProfileMath.elapsedTickTarget,
      AxisDomain.labelCapacity(plotWidth, spacing: Self.elapsedLabelSpacing))
    return DiveProfileMath.elapsedTicks(duration: duration, target: target).map {
      ProfileAxisLabel(
        position: Double($0), text: DiveProfileMath.formatElapsed(milliseconds: Double($0)))
    }
  }

  /// The chart with the channels in `hidden` switched off: where each scale goes, each
  /// shown line's domain, and the rows under the depth plot.
  public func layout(hiding hidden: Set<ProfileChannel>) -> ProfileChartLayout {
    ProfileChartLayout(chart: self, visible: Set(availableChannels).subtracting(hidden))
  }

  static let elapsedLabelSpacing = 44.0
}

/// One curve: a channel, or one cylinder of tank pressure.
public struct ProfileChartLine: Hashable, Sendable, Identifiable {
  public var id: String
  /// `Tank pressure (tank 2)` on a dive with two cylinders, the channel's own label
  /// otherwise.
  public var label: String
  public var series: ChannelSeries
  public var runs: ProfileRuns
  /// The domain a depth-plot line is scaled against, fixed whatever else is shown; nil for
  /// a line on a row under it, whose row is fitted to the channels shown on it.
  var ownDomain: AxisDomain?

  public var channel: ProfileChannel { series.display.channel }

  /// The readings that reached the picture. Everything that takes an extreme reads these,
  /// so a sample dropped from an undrawable run cannot stretch an axis or a summary.
  public var drawnValues: [Double] {
    runs.drawn.sorted().map { series.values[$0] }
  }
}

/// A marker: where it is, what it says, and how it is drawn.
public struct ProfileChartEvent: Hashable, Sendable {
  public enum Glyph: Hashable, Sendable {
    /// A gas switch.
    case diamond
    /// A stop, prescribed or broken.
    case triangle
    /// Everything else, an unknown or absent type included.
    case circle
  }

  public var time: Int
  public var text: String
  public var glyph: Glyph
  /// A gas switch joins to a pressure curve and is drawn in the cylinders' colour; no other
  /// marker joins to anything.
  public var joinsPressure: Bool

  init(_ event: DiveProfileEvent, cylinders: [Int?]) {
    time = event.time
    text = DiveProfileMath.describeEvent(
      time: event.time, type: event.type, gasNumber: event.gasNumber, label: event.label,
      cylinders: cylinders)
    let kind = event.type.flatMap(ProfileEventKind.init(rawValue:))
    joinsPressure = kind == .gasSwitch
    switch kind {
    case .gasSwitch: glyph = .diamond
    case .deepStop, .safetyStop, .safetyStopMandatory, .safetyStopViolation, .deepStopViolation:
      glyph = .triangle
    default: glyph = .circle
    }
  }
}

/// A label on an axis: where along it, and the Kit's string for it, drawn verbatim.
public struct ProfileAxisLabel: Hashable, Sendable {
  /// A value on the time axis in milliseconds, or a distance down a band from 0 at its top
  /// to 1 at its bottom.
  public var position: Double
  public var text: String
  /// A second scale's number at the same height, drawn under ``text``.
  public var under: String?

  public init(position: Double, text: String, under: String? = nil) {
    self.position = position
    self.text = text
    self.under = under
  }
}

/// A point of a line, on the time axis and down its band.
public struct ProfilePoint: Hashable, Sendable {
  public var time: Double
  /// 0 at the band's top edge, 1 at its bottom.
  public var offset: Double
}
