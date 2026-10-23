import OpenDivingKit
import Testing

/// Transcribed from `src/lib/dive-profile.test.ts` and `src/lib/chart-path.test.ts` at
/// `opendiving-web` `ec014ff9`; each test names the lines it came from. Times are the
/// profile's milliseconds and values the wire's integers, as the API serves them.
struct DiveProfileMathTests {
  private typealias Math = DiveProfileMath

  private func values(
    _ channel: ProfileChannel, _ times: [Int], _ values: [Int], _ units: UnitSystem = .metric
  ) -> [Double]? {
    Math.series(channel, times: times, values: values, units: units)?.values
  }

  // MARK: Scaling — `dive-profile.test.ts:126-205`, `:306-321`, `:1147-1190`

  /// `:132` — 139 cm is 1.39 m; `139 * 0.01` would be 1.3900000000000001.
  @Test func dividesByTheChannelsScaleExactly() {
    #expect(
      values(.depth, [0, 10_000, 20_000, 30_000], [139, 372, 632, 88]) == [1.39, 3.72, 6.32, 0.88])
  }

  /// `:142`.
  @Test func hundredthsOfADegreeWithoutNoise() {
    #expect(values(.temperature, [0, 1], [2069, 2060]) == [20.69, 20.6])
  }

  /// `:147-158`, `:168`.
  @Test(
    arguments: [([2669, 2711, 2690], 2), ([2360, 2350, 2340], 1), ([2700, 2600, 2700], 0)]
      as [([Int], Int)])
  func temperatureQuotesItsGrain(readings: [Int], decimals: Int) {
    let series = Math.series(.temperature, times: [0, 1, 2], values: readings, units: .metric)
    #expect(series?.display.decimals == decimals)
  }

  @Test func fahrenheitIsWholeWhateverTheGrain() {
    let series = Math.series(.temperature, times: [0, 1], values: [2669, 2711], units: .imperial)
    #expect(series?.display.decimals == 0)
  }

  /// `:178-201`.
  @Test func otherChannelsKeepTheirDecimalsAndAnEmptyChannelIsNone() {
    #expect(
      Math.series(.depth, times: [0, 1], values: [1000, 2000], units: .metric)?.display.decimals
        == 1)
    #expect(Math.series(.depth, times: [], values: [], units: .metric) == nil)
    #expect(ProfileChannel.depth.isInverted)
    #expect(!ProfileChannel.temperature.isInverted)
  }

  /// `:219-220`.
  @Test func pressureIsPerCylinderInTenthsOfABar() {
    let series = Math.series(
      .pressure, times: [0, 10_000], values: [2074, 2051], units: .metric, gasNumber: 0)
    #expect(series?.gasNumber == 0)
    #expect(series?.values == [207.4, 205.1])
  }

  /// `:316-317` — a ceiling divides by depth's scale.
  @Test func ceilingDividesByDepthsScale() {
    #expect(values(.ceiling, [730_000, 940_000], [300, 323]) == [3, 3.23])
    #expect(ProfileChannel.ceiling.scale == ProfileChannel.depth.scale)
  }

  /// `:336`, `:654` — the ceiling alone is dashed and alone has meaningful gaps.
  @Test func ceilingIsTheOneComputedCurve() {
    #expect(ProfileChannel.allCases.filter(\.isDashed) == [.ceiling])
    #expect(ProfileChannel.allCases.filter(\.gapsAreMeaningful) == [.ceiling])
  }

  /// `:1164-1186`.
  @Test func decoChannelsScale() {
    #expect(values(.ndl, [0, 60_000], [5940, 0]) == [99, 0])
    #expect(values(.tts, [0, 60_000], [0, 1080]) == [0, 18])
    #expect(values(.ppo2, [0, 60_000], [21, 132]) == [0.21, 1.32])
    #expect(values(.cns, [0, 60_000], [0, 234]) == [0, 23.4])
    #expect(values(.gradientFactor, [0, 60_000], [0, 12575]) == [0, 12575])
    #expect(values(.surfaceGradientFactor, [0, 60_000], [0, 87]) == [0, 87])
  }

  /// `:1189-1206` — none of the six converts.
  @Test(arguments: [ProfileChannel.ndl, .tts, .ppo2, .cns, .gradientFactor, .surfaceGradientFactor])
  func decoChannelsReadTheSameInImperial(channel: ProfileChannel) {
    #expect(
      values(channel, [0, 60_000], [21, 132], .imperial)
        == values(channel, [0, 60_000], [21, 132]))
    #expect(channel.display(.imperial) == channel.display(.metric))
  }

  /// `:1067-1093`.
  @Test func imperialConvertsAfterTheScale() {
    let depth = Math.series(.depth, times: [0], values: [139], units: .imperial)
    #expect(depth?.display.unit == "ft")
    #expect(depth?.display.decimals == 0)
    #expect(abs(depth!.values[0] - 139.0 / 100 / 0.3048) < 1e-10)

    let pressure = Math.series(.pressure, times: [0], values: [2000], units: .imperial)
    #expect(pressure?.display.unit == "psi")
    #expect(abs(pressure!.values[0] - 200 * 14.503773773020923) < 1e-8)

    #expect(values(.ceiling, [0], [3048], .imperial) == values(.depth, [0], [3048], .imperial))
  }

  /// `:1099-1102`, `:1221-1223`.
  @Test func spokenUnits() {
    #expect(ProfileChannel.depth.word(.imperial) == "feet")
    #expect(ProfileChannel.ceiling.word(.imperial) == "feet")
    #expect(ProfileChannel.temperature.word(.imperial) == "degrees Fahrenheit")
    #expect(ProfileChannel.pressure.word(.imperial) == "psi")
    #expect(ProfileChannel.ndl.word(.metric) == "minutes")
    #expect(ProfileChannel.ppo2.word(.imperial) == "bar")
    #expect(ProfileChannel.cns.word(.metric) == "percent")
  }

  /// `dive-profile.ts:267-278` — the plot, legend and readout order.
  @Test func channelOrder() {
    #expect(
      ProfileChannel.allCases.map(\.rawValue) == [
        "depth", "ceiling", "temperature", "pressure", "ndl", "tts", "ppo2", "cns",
        "surface_gradient_factor", "gradient_factor",
      ])
  }

  // MARK: Readouts — `:1105-1143`, `:1210-1216`

  @Test func readoutsAtTheChannelsResolution() {
    #expect(ProfileChannel.temperature.display(.imperial).format(75.2) == "75°F")
    #expect(ProfileChannel.depth.display(.imperial).format(100) == "100 ft")
    #expect(ProfileChannel.depth.display(.metric).format(16.9) == "16.9 m")
    #expect(ProfileChannel.temperature.display(.metric).format(21.62) == "21.62°C")
    #expect(ProfileChannel.pressure.display(.metric).format(205.2) == "205 bar")
    #expect(ProfileChannel.tts.display(.metric).format(18) == "18 min")
    #expect(ProfileChannel.ppo2.display(.metric).format(1.32) == "1.32 bar")
    #expect(ProfileChannel.cns.display(.metric).format(23.4) == "23.4%")
    #expect(ProfileChannel.gradientFactor.display(.metric).format(87) == "87%")
  }

  /// `:1119-1129`.
  @Test(
    arguments: [
      ([2700, 2600, -100, 0], 0), ([2360, 2350, -10], 1), ([2700, 2600, 2601, 2700], 2),
      ([-150, -151], 2),
    ] as [([Int], Int)])
  func grainDecimals(readings: [Int], decimals: Int) {
    #expect(Math.grainDecimals(readings, scale: 100) == decimals)
  }

  @Test func wholeUnitChannelHasNoGrainToNarrow() {
    #expect(Math.grainDecimals([87, 90], scale: 1) == 0)
  }

  // MARK: Spurious zeros — `:228-302`

  private func spaced(_ values: [Int]) -> [Int] {
    values.indices.map { $0 * 10_000 }
  }

  @Test func dropsAZeroAfterTheReadingItCannotFallFrom() {
    let cleaned = Math.withoutSpuriousZeros(
      times: spaced([6000, 6000, 0]), values: [6000, 6000, 0], after: 6000)
    #expect(cleaned.times == [0, 10_000])
    #expect(cleaned.values == [6000, 6000])
  }

  @Test func dropsTheWholeRunOfZeros() {
    let readings = [6000, 0, 0, 0, 6000, 5880]
    let cleaned = Math.withoutSpuriousZeros(times: spaced(readings), values: readings, after: 6000)
    #expect(cleaned.times == [0, 40_000, 50_000])
    #expect(cleaned.values == [6000, 6000, 5880])
  }

  @Test func keepsAZeroCountedDownToOrOpenedWith() {
    for readings in [[6000, 300, 60, 0, 0], [0, 6000]] {
      let cleaned = Math.withoutSpuriousZeros(
        times: spaced(readings), values: readings, after: 6000)
      #expect(cleaned.values == readings)
    }
  }

  /// `:264-302`: only the no-deco limit and the surface gradient factor are filtered.
  @Test func filtersOnlyTheTwoChannelsThatWriteSpuriousZeros() {
    #expect(values(.ndl, [0, 10_000], [6000, 0]) == [100])
    #expect(values(.tts, [0, 10_000], [6000, 0]) == [100, 0])
    let glitched = [29, 0, 30, 0, 30, 2, 1, 0]
    #expect(values(.surfaceGradientFactor, spaced(glitched), glitched) == [29, 30, 30, 2, 1, 0])
    #expect(values(.gradientFactor, [0, 10_000], [40, 0]) == [40, 0])
  }

  // MARK: The dive's end — `:63-123`

  @Test func cutsAtTheDivesEnd() {
    #expect(Math.chartDuration(duration: 40_000, diveEndTime: 20_000) == 20_000)
    let depth = Math.cut(
      times: [0, 10_000, 20_000, 30_000, 40_000], values: [0, 1800, 90, 10, 0], duration: 40_000,
      diveEndTime: 20_000)
    #expect(depth.times == [0, 10_000, 20_000])
    #expect(depth.values == [0, 1800, 90])
    let temperature = Math.cut(
      times: [5_000, 15_000, 25_000, 35_000], values: [2190, 2180, 3000, 3100], duration: 40_000,
      diveEndTime: 20_000)
    #expect(temperature.times == [5_000, 15_000])
    #expect(temperature.values == [2190, 2180])
    let ndl = Math.cut(
      times: [25_000, 35_000], values: [5940, 5940], duration: 40_000, diveEndTime: 20_000)
    #expect(ndl.times.isEmpty && ndl.values.isEmpty)
  }

  @Test(arguments: [nil, 40_000] as [Int?])
  func leavesTheProfileWholeWithNoEarlierEnd(end: Int?) {
    #expect(Math.chartDuration(duration: 40_000, diveEndTime: end) == 40_000)
    let whole = Math.cut(times: [0, 30_000], values: [1, 2], duration: 40_000, diveEndTime: end)
    #expect(whole.times == [0, 30_000])
  }

  // MARK: Gaps and runs — `:834-869`, `:554-578`; `chart-path.test.ts:129-163`

  @Test func gapThresholdFollowsTheCadence() {
    #expect(Math.gapThreshold([0, 10_000, 20_000, 30_000, 40_000]) == 30_000)
    #expect(Math.gapThreshold([0, 1_000, 2_000, 3_000, 4_000]) == 15_000)
    #expect(Math.minimumGapMilliseconds == 15_000)
    let quick = [0, 250, 500, 750, 1_000, 2_000, 2_250]
    #expect(Math.gapThreshold(quick) == 15_000)
    #expect(Math.segmentByTimeGap(quick, maxGap: Math.gapThreshold(quick)).count == 1)
    let dropout = [0, 10_000, 20_000, 620_000, 630_000, 640_000]
    #expect(Math.gapThreshold(dropout) == 30_000)
    #expect(Math.segmentByTimeGap(dropout, maxGap: Math.gapThreshold(dropout)).count == 2)
    #expect(Math.gapThreshold([0, 10_000]) == .infinity)
    #expect(Math.segmentByTimeGap([0, 10_000], maxGap: .infinity) == [[0, 1]])
  }

  @Test func readoutToleranceIsFinite() {
    let ceiling = [730_000, 800_000]
    #expect(Math.gapThreshold(ceiling) == .infinity)
    #expect(Math.readoutTolerance(ceiling) == 15_000)
    #expect(Math.segmentByTimeGap([730_000], maxGap: Math.gapThreshold([730_000])) == [[0]])
  }

  @Test func segmentsByTimeGap() {
    #expect(Math.segmentByTimeGap([0, 10_000, 20_000, 30_000], maxGap: 30_000) == [[0, 1, 2, 3]])
    #expect(
      Math.segmentByTimeGap([0, 10_000, 20_000, 620_000, 630_000], maxGap: 30_000)
        == [[0, 1, 2], [3, 4]])
    #expect(Math.segmentByTimeGap([0, 30_000, 60_000], maxGap: 30_000) == [[0, 1, 2]])
    #expect(Math.segmentByTimeGap([], maxGap: 30_000) == [])
    #expect(Math.segmentByTimeGap([42_000], maxGap: 30_000) == [[0]])
    let day = 24 * 60 * 60 * 1000
    let flat = Math.segmentByTimeGap(
      [0, 100 * day, 101 * day, 500 * day], maxGap: Double(60 * day))
    #expect(Array(flat.joined()) == [0, 1, 2, 3])
  }

  /// `dive-profile-chart.tsx:451-482`, the chart's `runs`: the ceiling is cut at the
  /// finite tolerance and loses its single-sample runs; a measured channel joins two
  /// samples however far apart.
  @Test func runsTreatTheCeilingsGapsAsMeaningful() {
    let twoApart = [730_000, 800_000]
    let ceiling = Math.runs(times: twoApart, channel: .ceiling)
    #expect(ceiling.segments.isEmpty)
    #expect(ceiling.drawn.isEmpty)
    #expect(ceiling.readoutTolerance == 15_000)
    let depth = Math.runs(times: twoApart, channel: .depth)
    #expect(depth.segments == [[0, 1]])
    #expect(depth.drawn == [0, 1])
    #expect(
      Math.runs(times: [0, 10_000, 600_000, 610_000], channel: .ceiling).segments == [
        [0, 1], [2, 3],
      ])
  }

  // MARK: The time axis — `:919-988`

  @Test func elapsedTicksAreRoundMinutes() {
    let minute = 60_000
    #expect(
      Math.elapsedTicks(duration: 12 * minute) == [0, 2, 4, 6, 8, 10, 12].map { $0 * minute })
    #expect(
      Math.elapsedTicks(duration: 50 * minute) == [0, 10, 20, 30, 40, 50].map { $0 * minute })
    #expect(
      Math.elapsedTicks(duration: 180 * minute)
        == [0, 30, 60, 90, 120, 150, 180].map { $0 * minute })
    #expect(Math.elapsedTicks(duration: 2_781_000).max()! <= 2_781_000)
    for duration in [720_000, 2_781_000, 3_000_000, 4_401_160, 10_800_000] {
      #expect(Math.elapsedTicks(duration: duration).allSatisfy { $0 % minute == 0 })
    }
    #expect(Math.elapsedTicks(duration: 0) == [0])
    #expect(
      Math.elapsedTicks(duration: 720 * minute, target: 4)
        == [0, 240, 480, 720].map { $0 * minute })
  }

  @Test(
    arguments: [
      (0.0, "0:00"), (600_000, "10:00"), (4_000_020, "66:40"), (160, "0:00"), (1_600, "0:02"),
    ] as [(Double, String)])
  func elapsedReadsAsMinutesAndSeconds(milliseconds: Double, expected: String) {
    #expect(Math.formatElapsed(milliseconds: milliseconds) == expected)
  }

  @Test func elapsedSpoken() {
    #expect(Math.formatElapsedSpoken(milliseconds: 1_500_000) == "25min")
    #expect(Math.formatElapsedSpoken(milliseconds: 5_100_000) == "1h 25min")
  }

  // MARK: Cylinders and events — `:658-831`

  @Test func cylinderNames() {
    #expect(Math.cylinderName(gasNumber: 0, cylinders: [0, 1]) == "tank 1")
    #expect(Math.cylinderName(gasNumber: 1, cylinders: [0, 1]) == "tank 2")
    #expect(Math.cylinderName(gasNumber: 0, cylinders: [1, 0]) == "tank 2")
    #expect(Math.cylinderName(gasNumber: 3, cylinders: [0, nil]) == "gas 3")
    #expect(Math.cylinderName(gasNumber: 0, cylinders: []) == "gas 0")
    #expect(Math.cylinderName(gasNumber: 1, cylinders: [1, 1]) == "gas 1")
  }

  @Test func gasSwitchSentences() {
    let switchAt = 600_000
    #expect(
      Math.describeEvent(time: 910, type: "gas_switch", gasNumber: 0, label: nil, cylinders: [0])
        == "Dive started")
    #expect(
      Math.describeEvent(time: 30_001, type: "gas_switch", gasNumber: 0, label: nil, cylinders: [0])
        == "Gas switch to tank 1")
    #expect(
      Math.describeEvent(
        time: switchAt, type: "gas_switch", gasNumber: 1, label: nil, cylinders: [0, 1])
        == "Gas switch to tank 2")
    #expect(
      Math.describeEvent(
        time: switchAt, type: "gas_switch", gasNumber: 0, label: nil, cylinders: [0])
        == "Gas switch to tank 1")
    #expect(
      Math.describeEvent(time: switchAt, type: "gas_switch", gasNumber: 0, label: nil)
        == "Gas switch to gas 0")
    #expect(
      Math.describeEvent(time: switchAt, type: "gas_switch", gasNumber: nil, label: nil)
        == "Gas switch")
  }

  @Test(
    arguments: [
      ("deep_stop", "Deep stop"), ("safety_stop", "Safety stop"), ("bookmark", "Bookmark"),
      ("ascent_rate", "Ascent rate"), ("safety_stop_mandatory", "Mandatory safety stop"),
      ("safety_stop_violation", "Safety stop broken"), ("deep_stop_violation", "Deep stop broken"),
      ("ceiling_violation", "Deco ceiling broken"), ("ndl_reached", "No-deco limit reached"),
      ("ppo2_high", "ppO\u{2082} high"), ("pressure_low", "Tank pressure low"),
      ("depth_alarm", "Depth alarm"),
    ] as [(String, String)])
  func classifiedEventSentences(type: String, expected: String) {
    #expect(Math.describeEvent(time: 0, type: type, gasNumber: nil, label: nil) == expected)
  }

  @Test func unclassifiedEventsSayTheDevicesOwnWords() {
    #expect(
      Math.describeEvent(time: 0, type: nil, gasNumber: nil, label: "Mandatory Safety Stop")
        == "Mandatory Safety Stop")
    #expect(
      Math.describeEvent(time: 10, type: nil, gasNumber: nil, label: "Violated Deep Stop")
        == "Violated Deep Stop")
    #expect(
      Math.describeEvent(time: 10, type: "other", gasNumber: nil, label: "Ceiling Broken")
        == "Ceiling Broken")
    #expect(
      Math.describeEvent(
        time: 10, type: "setpoint_change", gasNumber: nil, label: "Setpoint Change")
        == "Setpoint Change")
    #expect(
      Math.describeEvent(time: 10, type: "setpoint_change", gasNumber: nil, label: nil)
        == "Device event")
    #expect(Math.describeEvent(time: 0, type: nil, gasNumber: nil, label: nil) == "Device event")
    #expect(Math.describeEvent(time: 0, type: nil, gasNumber: nil, label: "  ") == "Device event")
  }

  @Test func thirteenClassifiedKinds() {
    #expect(ProfileEventKind.allCases.count == 13)
  }
}
