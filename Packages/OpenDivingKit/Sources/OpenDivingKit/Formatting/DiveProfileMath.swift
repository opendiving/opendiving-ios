/// The profile chart's arithmetic, over plain series: `times` in milliseconds from the
/// recording's start and `values` in the wire's integer scale, exactly as
/// `GET /dive/{uuid}/recording/{rid}/profile` serves them.
public enum DiveProfileMath {
  /// How far into a recording a gas switch is the computer logging the gas the dive
  /// starts on rather than a switch.
  public static let startingGasMilliseconds = 30_000
  /// The least gap that breaks a line, however fast the cadence.
  public static let minimumGapMilliseconds = 15_000.0
  /// Steps the time axis may take, minute-shaped throughout.
  static let elapsedSteps = [1, 2, 5, 10, 15, 30, 60, 120].map { $0 * 60_000 }
  /// How many elapsed-time steps the axis aims for.
  public static let elapsedTickTarget = 6

  /// A channel's readings in display units, or nil when it recorded none. Divides by
  /// the wire scale — never multiplies by its reciprocal, which turns `139` into
  /// `1.3900000000000001` — and only then converts to `units`. A no-deco limit's and a
  /// surface gradient factor's spurious zeros are dropped first, and a temperature's
  /// decimals narrow to the grain its readings carry.
  public static func series(
    _ channel: ProfileChannel, times: [Int], values: [Int], units: UnitSystem,
    gasNumber: Int? = nil
  ) -> ChannelSeries? {
    var times = times
    var values = values
    if let after = channel.spuriousZeroAfter {
      (times, values) = withoutSpuriousZeros(times: times, values: values, after: after)
    }
    guard !times.isEmpty else { return nil }

    var display = channel.display(units)
    if channel == .temperature {
      display.decimals = min(display.decimals, grainDecimals(values, scale: channel.scale))
    }
    let scale = Double(channel.scale)
    let converted = values.map { value -> Double in
      let scaled = Double(value) / scale
      guard let measure = channel.measure else { return scaled }
      return measure.toDisplay(scaled, units)
    }
    return ChannelSeries(display: display, times: times, values: converted, gasNumber: gasNumber)
  }

  /// A series without its spurious zeros: a run of zeros straight after a reading of at
  /// least `after` is dropped whole, up to the next non-zero reading, while a zero
  /// reached by counting down is real and stays.
  public static func withoutSpuriousZeros(times: [Int], values: [Int], after: Int)
    -> (times: [Int], values: [Int])
  {
    var kept: [Int] = []
    var spurious = false
    for (index, value) in values.enumerated() {
      if value != 0 {
        spurious = false
      } else if index > 0 && values[index - 1] >= after {
        spurious = true
      }
      if !spurious { kept.append(index) }
    }
    if kept.count == values.count { return (times, values) }
    return (kept.map { times[$0] }, kept.map { values[$0] })
  }

  /// The fewest decimals that state every stored integer exactly once divided by
  /// `scale`, a power of ten: 2 for hundredths with an odd hundredth among them, 1 where
  /// all are whole tenths, 0 where all are whole units.
  public static func grainDecimals(_ values: [Int], scale: Int) -> Int {
    var decimals = 0
    var step = scale
    while step > 1 {
      if values.allSatisfy({ $0 % step == 0 }) { return decimals }
      step /= 10
      decimals += 1
    }
    return decimals
  }

  /// The chart's duration: the dive's end where the read carries one short of the
  /// recording's own, since a computer goes on recording at the surface.
  public static func chartDuration(duration: Int, diveEndTime: Int?) -> Int {
    guard let diveEndTime, diveEndTime < duration else { return duration }
    return diveEndTime
  }

  /// One series cut at the dive's end: the sample at the end is kept and every one after
  /// it dropped. Unchanged where there is no end, or the end is the recording's own.
  public static func cut(times: [Int], values: [Int], duration: Int, diveEndTime: Int?)
    -> (times: [Int], values: [Int])
  {
    guard let diveEndTime, diveEndTime < duration,
      let past = times.firstIndex(where: { $0 > diveEndTime })
    else { return (times, values) }
    return (Array(times[..<past]), Array(values[..<past]))
  }

  /// How far apart two samples must be before a line between them would claim something
  /// nobody recorded: three times the median spacing, never under 15 s, and infinite for
  /// a series too short to have a cadence.
  public static func gapThreshold(_ times: [Int]) -> Double {
    guard times.count >= 3 else { return .infinity }
    let deltas = zip(times.dropFirst(), times).map { $0 - $1 }.sorted()
    let median = deltas[deltas.count / 2]
    return max(minimumGapMilliseconds, Double(median * 3))
  }

  /// ``gapThreshold(_:)`` made finite, for comparing a distance against: the readout's
  /// reach, and on the ceiling the line's cut as well.
  public static func readoutTolerance(_ times: [Int]) -> Double {
    let threshold = gapThreshold(times)
    return threshold.isFinite ? threshold : minimumGapMilliseconds
  }

  /// Runs of indices whose neighbours sit no further than `maxGap` apart.
  public static func segmentByTimeGap(_ times: [Int], maxGap: Double) -> [[Int]] {
    guard !times.isEmpty else { return [] }
    var segments: [[Int]] = [[0]]
    for index in 1..<times.count {
      if Double(times[index] - times[index - 1]) > maxGap {
        segments.append([index])
      } else {
        segments[segments.count - 1].append(index)
      }
    }
    return segments
  }

  /// A channel's drawable runs. A measured channel breaks at its gap threshold; the
  /// ceiling, whose gaps mean no obligation, breaks at the finite readout tolerance and
  /// drops a run of one sample, which draws nothing.
  public static func runs(times: [Int], channel: ProfileChannel) -> ProfileRuns {
    let tolerance = readoutTolerance(times)
    let cut = channel.gapsAreMeaningful ? tolerance : gapThreshold(times)
    let segments = segmentByTimeGap(times, maxGap: cut).filter {
      !channel.gapsAreMeaningful || $0.count > 1
    }
    return ProfileRuns(
      readoutTolerance: tolerance, segments: segments, drawn: Set(segments.joined()))
  }

  /// The elapsed-time gridlines for `duration` milliseconds, from 0 and never past the
  /// end: the first minute-shaped step giving at most `target` ticks, doubled past the
  /// longest step until one does.
  public static func elapsedTicks(duration: Int, target: Int = elapsedTickTarget) -> [Int] {
    guard duration > 0 else { return [0] }
    let fits = { (step: Int) in Double(duration) / Double(step) <= Double(target) }
    var step = elapsedSteps.first(where: fits) ?? elapsedSteps[elapsedSteps.count - 1]
    while !fits(step) { step *= 2 }
    return Array(stride(from: 0, through: duration, by: step))
  }

  /// An axis instant as `M:SS`, rounded to the second, minutes unpadded: `66:40`.
  public static func formatElapsed(milliseconds: Double) -> String {
    let seconds = NumberText.round(milliseconds / 1000)
    let minutes = (seconds / 60).rounded(.down)
    return NumberText.plain(minutes) + ":" + pad(seconds - minutes * 60)
  }

  /// A span read aloud — `1h 25min` rather than `85:00`.
  public static func formatElapsedSpoken(milliseconds: Double) -> String {
    DateText.hoursMinutes(seconds: milliseconds / 1000)
  }

  /// What to call the cylinder a pressure series or a gas switch names by its gas
  /// number: `tank N` by its 1-based position on the Tanks card where exactly one of the
  /// dive's cylinders carries that number, and `gas N` otherwise — a bare number would
  /// read as a row of the card. `cylinders` is each cylinder's gas number, in the
  /// card's order.
  public static func cylinderName(gasNumber: Int, cylinders: [Int?]) -> String {
    let positions = cylinders.indices.filter { cylinders[$0] == gasNumber }
    return positions.count == 1 ? "tank \(positions[0] + 1)" : "gas \(gasNumber)"
  }

  /// What a marker says. A gas switch in the opening 30 s is the gas the dive started
  /// on; a later one names its cylinder as ``cylinderName(gasNumber:cylinders:)`` does.
  /// An event with no type, or one this build does not know, says the device's own
  /// label, and `Device event` where that is blank.
  public static func describeEvent(
    time: Int, type: String?, gasNumber: Int?, label: String?, cylinders: [Int?] = []
  ) -> String {
    guard let kind = type.flatMap(ProfileEventKind.init(rawValue:)) else {
      let own = label?.trimmedOfWhitespace ?? ""
      return own.isEmpty ? "Device event" : own
    }
    if let sentence = kind.sentence { return sentence }
    if time <= startingGasMilliseconds { return "Dive started" }
    guard let gasNumber else { return "Gas switch" }
    return "Gas switch to " + cylinderName(gasNumber: gasNumber, cylinders: cylinders)
  }

  private static func pad(_ value: Double) -> String {
    let text = NumberText.plain(value)
    return text.count < 2 ? "0" + text : text
  }
}
