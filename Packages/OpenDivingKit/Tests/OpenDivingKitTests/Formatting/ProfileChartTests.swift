import Foundation
import OpenDivingKit
import Testing

/// The chart's data preparation, against the semantics of `dive-profile-chart.tsx` and
/// `dive-profile.ts` at `opendiving-web` `50c8ce78`. Profiles are built as the API serves
/// them: milliseconds and the wire's integers.
struct ProfileChartTests {
  // MARK: Building a profile

  private struct Series {
    var times: [Int]
    var values: [Int]
    var json: String { #"{"times":\#(times),"values":\#(values)}"# }
  }

  private func profile(
    duration: Int = 60_000, diveEnd: Int? = nil, depth: Series? = nil, ceiling: Series? = nil,
    temperature: Series? = nil, pressures: [(Int, Series)] = [], ndl: Series? = nil,
    tts: Series? = nil, ppo2: Series? = nil, cns: Series? = nil,
    gradientFactor: Series? = nil, surfaceGradientFactor: Series? = nil,
    events: [String] = []
  ) throws -> RecordingProfileRead {
    func field(_ name: String, _ series: Series?) -> String {
      "\"\(name)\":\(series?.json ?? "null")"
    }
    let cylinders = pressures.map { number, series in
      #"{"times":\#(series.times),"values":\#(series.values),"gas_number":\#(number)}"#
    }
    let fields = [
      "\"duration\":\(duration)",
      field("depth", depth), field("ceiling", ceiling), field("temperature", temperature),
      "\"pressures\":[\(cylinders.joined(separator: ","))]",
      field("ndl", ndl), field("tts", tts), field("ppo2", ppo2), field("cns", cns),
      field("gradient_factor", gradientFactor),
      field("surface_gradient_factor", surfaceGradientFactor),
      "\"events\":[\(events.joined(separator: ","))]",
      "\"provenance\":\"file\"",
      "\"dive_end_time\":\(diveEnd.map(String.init) ?? "null")",
    ]
    return try APICoding.decoder().decode(
      RecordingProfileRead.self, from: Data("{\(fields.joined(separator: ","))}".utf8))
  }

  private let tenSeconds = [0, 10_000, 20_000, 30_000, 40_000, 50_000, 60_000]

  private func chart(
    _ profile: RecordingProfileRead, units: UnitSystem = .metric, cylinders: [Int?] = []
  ) -> ProfileChart {
    ProfileChart(profile: profile, units: units, cylinders: cylinders)
  }

  // MARK: The cut at the dive's end — `dive-profile.ts:666-701`

  @Test func everySeriesEndsAtTheDivesEnd() throws {
    let built = chart(
      try profile(
        duration: 60_000, diveEnd: 30_000,
        depth: Series(times: tenSeconds, values: [0, 500, 1000, 200, 0, 0, 0]),
        temperature: Series(times: tenSeconds, values: [2700, 2650, 2600, 2650, 2700, 2900, 3100]),
        pressures: [
          (1, Series(times: tenSeconds, values: [2000, 1900, 1800, 1700, 1600, 1600, 1600]))
        ],
        events: [#"{"time":50000,"type":"bookmark","gas_number":null,"label":null}"#]))

    #expect(built.duration == 30_000)
    for line in built.lines {
      #expect(line.series.times == [0, 10_000, 20_000, 30_000], "\(line.id)")
    }
    // The surface stretch is out of temperature's scale as well as off the plot.
    let temperature = try #require(built.lines.first { $0.channel == .temperature })
    #expect(temperature.series.values.max() == 27)
    // Markers past the end are dropped, not clamped.
    #expect(built.events.isEmpty)
  }

  @Test func aProfileWithNoEndIsWhole() throws {
    let built = chart(
      try profile(
        duration: 60_000, depth: Series(times: tenSeconds, values: [0, 1, 2, 3, 4, 5, 6])))
    #expect(built.duration == 60_000)
    #expect(built.lines.first?.series.times == tenSeconds)
  }

  // MARK: Lines — `dive-profile-chart.tsx:445-620`

  @Test func linesComeInPlotOrderWithTheirOwnScales() throws {
    let built = chart(
      try profile(
        depth: Series(times: tenSeconds, values: [0, 1520, 3010, 2000, 1000, 450, 0]),
        ceiling: Series(times: [20_000, 30_000], values: [300, 300]),
        temperature: Series(times: tenSeconds, values: [2719, 2701, 2650, 2690, 2700, 2700, 2700]),
        pressures: [
          (1, Series(times: tenSeconds, values: [2000, 1900, 1800, 1700, 1600, 1500, 1400])),
          (2, Series(times: [20_000, 30_000, 40_000], values: [2000, 1950, 1900])),
        ],
        ndl: Series(times: tenSeconds, values: [5940, 3000, 600, 300, 600, 3000, 5940]),
        tts: Series(times: tenSeconds, values: [0, 60, 420, 300, 120, 60, 0]),
        cns: Series(times: tenSeconds, values: [80, 85, 90, 92, 93, 94, 95]),
        gradientFactor: Series(times: tenSeconds, values: [0, 10, 20, 30, 40, 30, 20]),
        surfaceGradientFactor: Series(times: tenSeconds, values: [0, 5, 10, 15, 20, 15, 10])),
      cylinders: [1, 2])

    #expect(
      built.lines.map(\.id) == [
        "depth", "ceiling", "temperature", "pressure-0", "pressure-1", "ndl", "tts", "cns",
        "surface_gradient_factor", "gradient_factor",
      ])
    #expect(
      built.lines.map(\.label)[3...4] == ["Tank pressure (tank 1)", "Tank pressure (tank 2)"])
    #expect(
      built.availableChannels == [
        .depth, .ceiling, .temperature, .pressure, .ndl, .tts, .cns, .surfaceGradientFactor,
        .gradientFactor,
      ])
  }

  /// One cylinder is named by the channel alone; without the dive's cylinders, two are
  /// `gas N` — `dive-profile-chart.tsx:562-565`, `dive-profile.ts:843-853`.
  @Test func pressureIsNamedOnlyWhenThereAreTwo() throws {
    let one = chart(
      try profile(pressures: [(3, Series(times: tenSeconds, values: [1, 2, 3, 4, 5, 6, 7]))]))
    #expect(one.lines.map(\.label) == ["Tank pressure"])

    let two = chart(
      try profile(pressures: [
        (0, Series(times: tenSeconds, values: [1, 2, 3, 4, 5, 6, 7])),
        (1, Series(times: tenSeconds, values: [1, 2, 3, 4, 5, 6, 7])),
      ]))
    #expect(two.lines.map(\.label) == ["Tank pressure (gas 0)", "Tank pressure (gas 1)"])
  }

  /// `dive-profile-chart.tsx:607-619`: a ceiling of isolated samples draws nothing, so it
  /// is not a line, and is offered no toggle.
  @Test func aLineWithNothingDrawableIsNotOnTheChart() throws {
    let built = chart(
      try profile(
        depth: Series(times: tenSeconds, values: [0, 1, 2, 3, 4, 5, 6]),
        ceiling: Series(times: [10_000, 50_000], values: [300, 900])))
    #expect(built.availableChannels == [.depth])
  }

  /// `dive-profile-chart.tsx:290-310`: the depth axis is fitted to what was drawn, so a
  /// dropped ceiling sample cannot stretch it.
  @Test func theDepthAxisReadsOnlyDrawnSamples() throws {
    let built = chart(
      try profile(
        duration: 2_100_000,
        depth: Series(times: [0, 600_000, 1_200_000, 2_000_000], values: [0, 400, 400, 0]),
        ceiling: Series(
          times: [600_000, 610_000, 620_000, 2_000_000], values: [300, 300, 300, 900])))
    let layout = built.layout(hiding: [])
    #expect(layout.plotted(.depth)?.domain == AxisDomain(min: 0, max: 4, step: 1))
  }

  @Test func spuriousZerosAreNotDrawn() throws {
    let built = chart(
      try profile(ndl: Series(times: tenSeconds, values: [6000, 6000, 0, 0, 3000, 600, 0])))
    let ndl = try #require(built.lines.first)
    #expect(ndl.series.values == [100, 100, 50, 10, 0])
  }

  @Test func aProfileWithNoSamplesHasNothingToPlot() throws {
    #expect(!chart(try profile()).hasSamples)
    #expect(!chart(try profile(depth: Series(times: [], values: []))).hasSamples)
  }

  // MARK: Placement — `dive-profile.ts:473-543`, `dive-profile.test.ts:1291-1420`

  private static let everySelection: [Set<ProfileChannel>] = (0..<1024).map { mask in
    Set(ProfileChannel.allCases.enumerated().filter { mask & (1 << $0.offset) != 0 }.map(\.element))
  }

  @Test func everySelectionLabelsTheDepthPlotsEdges() {
    for shown in Self.everySelection {
      let placement = ProfileScalePlacement(shown: shown)
      let scales = Set(
        shown.filter { [.depth, .ceiling, .temperature, .pressure].contains($0) }
          .map { $0 == .ceiling ? ProfileChannel.depth : $0 }
      ).count
      #expect((placement.left != nil) == (scales > 0))
      #expect((placement.right != nil) == (scales > 1))
      #expect((placement.underRight != nil) == (scales > 2))
      let named = [placement.left, placement.right, placement.underRight].compactMap { $0 }
      #expect(Set(named).count == named.count)

      for channel in shown {
        let housed =
          channel == placement.left || channel == placement.right || channel == .ceiling
          || channel == .pressure || placement.panels.contains(channel.axis)
        #expect(housed, "\(channel) in \(shown)")
      }
      for axis in placement.panels {
        #expect(shown.contains { $0.axis == axis })
      }
    }
  }

  @Test func scalesKeepTheirSides() {
    let depthAndTemperature = ProfileScalePlacement(shown: [.depth, .temperature])
    #expect(depthAndTemperature.left == .depth && depthAndTemperature.right == .temperature)
    let ceilingAndTemperature = ProfileScalePlacement(shown: [.ceiling, .temperature])
    #expect(ceilingAndTemperature.left == .ceiling && ceilingAndTemperature.right == .temperature)
    #expect(ProfileScalePlacement(shown: [.depth, .pressure]).right == .pressure)
    #expect(ProfileScalePlacement(shown: [.temperature, .pressure]).left == .pressure)
    let three = ProfileScalePlacement(shown: [.depth, .temperature, .pressure])
    #expect(three.left == .depth && three.right == .temperature && three.underRight == .pressure)
    let lone = ProfileScalePlacement(shown: [.temperature])
    #expect(lone.left == .temperature && lone.right == nil)
  }

  @Test func panelRowsStackInOneOrder() {
    let decoOnly = ProfileScalePlacement(shown: [.ndl, .cns])
    #expect(decoOnly.left == nil && decoOnly.right == nil && decoOnly.underRight == nil)
    #expect(decoOnly.panels == [.noDeco, .percent])
    #expect(
      ProfileScalePlacement(shown: [.cns, .ppo2, .tts, .ndl]).panels
        == [.noDeco, .timeToSurface, .ppo2, .percent])
    #expect(ProfileScalePlacement(shown: [.depth, .ceiling]).panels.isEmpty)
  }

  // MARK: Layout — `dive-profile-chart.tsx:722-815`

  private func decoProfile() throws -> RecordingProfileRead {
    try profile(
      depth: Series(times: tenSeconds, values: [0, 1000, 4590, 4000, 2000, 600, 0]),
      temperature: Series(times: tenSeconds, values: [2400, 2300, 2200, 2200, 2250, 2300, 2400]),
      pressures: [
        (1, Series(times: tenSeconds, values: [2100, 1900, 1600, 1300, 1000, 800, 600]))
      ],
      ndl: Series(times: tenSeconds, values: [5940, 2400, 0, 0, 0, 600, 5940]),
      tts: Series(times: tenSeconds, values: [0, 0, 600, 900, 480, 120, 0]),
      ppo2: Series(times: tenSeconds, values: [21, 42, 117, 105, 63, 33, 21]),
      cns: Series(times: tenSeconds, values: [0, 20, 60, 100, 140, 150, 152]),
      gradientFactor: Series(times: tenSeconds, values: [0, 10, 40, 14_060, 60, 40, 20]),
      surfaceGradientFactor: Series(times: tenSeconds, values: [0, 20, 80, 121, 90, 60, 30]))
  }

  @Test func ndlAndTtsTakeARowEach() throws {
    let layout = chart(try decoProfile()).layout(hiding: [])
    #expect(layout.placement.panels == [.noDeco, .timeToSurface, .ppo2, .percent])
    #expect(layout.panelRows.map(\.top) == ["100 min", "15 min", "1.2 bar", "200%"])
    #expect(layout.panelRows.map(\.bottom) == ["0", "0", "0.2", "0"])
    #expect(layout.plotted(.ndl)?.panelIndex == 0)
    #expect(layout.plotted(.tts)?.panelIndex == 1)
    #expect(layout.plotted(.depth)?.panelIndex == nil)
  }

  /// The owner's `gf99` fault: the percent row stops at 200 % while the readout quotes the
  /// device's figure, and the curve is drawn leaving the row.
  @Test func thePercentRowStopsAt200AndTheReadingDoesNot() throws {
    let layout = chart(try decoProfile()).layout(hiding: [])
    let gradient = try #require(layout.plotted(.gradientFactor))
    #expect(gradient.domain == AxisDomain(min: 0, max: 200, step: 50))

    let readout = try #require(layout.readouts(at: 30_000).first { $0.channel == .gradientFactor })
    #expect(readout.sample?.text == "14060%")
    #expect(readout.sample?.offScale == true)

    // The run climbs out through the top rule and comes back in: two pieces, each ending or
    // starting on the edge, nothing drawn above it.
    let paths = gradient.paths
    #expect(paths.count == 2)
    #expect(paths.allSatisfy { $0.allSatisfy { (0...1).contains($0.offset) } })
    #expect(paths[0].last?.offset == 0)
    #expect(paths[1].first?.offset == 0)
  }

  /// A hidden gradient factor does not set the row a CNS is shown on —
  /// `dive-profile-chart.tsx:737-768`.
  @Test func aRowIsFittedToTheChannelsShownOnIt() throws {
    let built = chart(try decoProfile())
    let cnsAlone = built.layout(hiding: [.gradientFactor, .surfaceGradientFactor])
    #expect(cnsAlone.plotted(.cns)?.domain == AxisDomain.nice([0, 2, 6, 10, 14, 15, 15.2]))
  }

  @Test func pressureIsNumberedUnderTemperature() throws {
    let layout = chart(try decoProfile()).layout(hiding: [])
    #expect(layout.placement.underRight == .pressure)
    let temperature = try #require(layout.plotted(.temperature)).domain
    let pressure = try #require(layout.plotted(.pressure)).domain
    #expect(pressure.stepCount == temperature.stepCount)
    let labels = layout.rightLabels
    #expect(labels.count == temperature.ticks.count)
    #expect(labels.allSatisfy { $0.under != nil })
    #expect(labels.map(\.text) == temperature.ticks.map(NumberText.plain))
  }

  @Test func withoutTemperaturePressureTakesTheRightEdge() throws {
    let layout = chart(try decoProfile()).layout(hiding: [.temperature])
    #expect(layout.placement.right == .pressure)
    #expect(
      layout.plotted(.pressure)?.domain == AxisDomain.nice([210, 190, 160, 130, 100, 80, 60]))
    #expect(layout.rightLabels.allSatisfy { $0.under == nil })
  }

  @Test func theDepthAxisIsInvertedAndReadsInTheDiversUnits() throws {
    let layout = chart(try decoProfile(), units: .imperial).layout(hiding: [])
    let depth = try #require(layout.plotted(.depth))
    #expect(depth.offset(depth.domain.min) == 0)
    #expect(depth.offset(depth.domain.max) == 1)
    #expect(layout.leftLabels.first?.text == "0")
    #expect(layout.leftLabels.first?.position == 0)
    #expect(depth.domain.max >= 45.9 / UnitFormat.metersPerFoot)
  }

  // MARK: Readouts — `dive-profile-chart.tsx:916-967`, `dive-profile.ts:1055-1169`

  @Test func everyVisibleLineKeepsItsRowWithADash() throws {
    let built = chart(
      try profile(
        duration: 700_000,
        depth: Series(
          times: [0, 10_000, 20_000, 620_000, 630_000, 640_000],
          values: [0, 1000, 1200, 1200, 600, 0]),
        temperature: Series(times: [0, 10_000, 20_000, 30_000], values: [2163, 2160, 2150, 2140])))
    let layout = built.layout(hiding: [])

    let inTheGap = layout.readouts(at: 300_000)
    #expect(inTheGap.map(\.label) == ["Depth", "Temperature"])
    #expect(inTheGap.allSatisfy { $0.sample == nil })

    let early = layout.readouts(at: 1_000)
    #expect(early.map { $0.sample?.text } == ["0.0 m", "21.63°C"])

    #expect(layout.readouts(at: nil).allSatisfy { $0.sample == nil })
  }

  @Test func readoutsQuoteTheRecordingsGrain() throws {
    let tenths = chart(
      try profile(
        temperature: Series(times: tenSeconds, values: [2160, 2150, 2140, 2130, 2120, 2110, 2100])))
    #expect(tenths.layout(hiding: []).readouts(at: 0).first?.sample?.text == "21.6°C")
    let pressure = chart(
      try profile(pressures: [
        (1, Series(times: tenSeconds, values: [380, 380, 380, 380, 380, 380, 380]))
      ]))
    #expect(pressure.layout(hiding: []).readouts(at: 0).first?.sample?.text == "38 bar")
    let depth = chart(
      try profile(
        depth: Series(times: tenSeconds, values: [1830, 1830, 1830, 1830, 1830, 1830, 1830])))
    #expect(depth.layout(hiding: []).readouts(at: 0).first?.sample?.text == "18.3 m")
  }

  @Test func aHiddenLineHasNoReadout() throws {
    let layout = chart(try decoProfile()).layout(hiding: [.temperature, .ndl])
    let channels = Set(layout.readouts(at: 0).map(\.channel))
    #expect(!channels.contains(.temperature) && !channels.contains(.ndl))
    #expect(channels.contains(.depth))
  }

  @Test func nearestSampleIndexMatchesTheWeb() {
    let times = [0, 10_000, 20_000, 30_000, 40_000]
    #expect(DiveProfileMath.nearestSampleIndex(times, at: 20_000) == 2)
    #expect(DiveProfileMath.nearestSampleIndex(times, at: 15_000) == 1)
    #expect(DiveProfileMath.nearestSampleIndex(times, at: 15_001) == 2)
    #expect(DiveProfileMath.nearestSampleIndex(times, at: -100_000) == 0)
    #expect(DiveProfileMath.nearestSampleIndex(times, at: 10_000_000) == 4)
    #expect(DiveProfileMath.nearestSampleIndex([], at: 10_000) == nil)
    let irregular = [0, 3_000, 47_000, 48_000, 900_000]
    #expect(DiveProfileMath.nearestSampleIndex(irregular, at: 400_000) == 3)
    #expect(DiveProfileMath.nearestSampleIndex(irregular, at: 500_000) == 4)
  }

  @Test func drawnSampleIndexSkipsAnUndrawnNeighbour() {
    let times = [1_000_000, 1_010_000, 1_020_000, 1_060_000]
    let drawn: Set = [0, 1, 2]
    #expect(
      DiveProfileMath.drawnSampleIndex(times, at: 1_045_000, tolerance: 30_000, drawn: drawn) == 2)
    #expect(
      DiveProfileMath.drawnSampleIndex(times, at: 1_080_000, tolerance: 30_000, drawn: drawn) == nil
    )
    let wide = [0, 100_000, 200_000]
    #expect(DiveProfileMath.drawnSampleIndex(wide, at: 190_000, tolerance: 30_000, drawn: [2]) == 2)
    #expect(
      DiveProfileMath.drawnSampleIndex(wide, at: 110_000, tolerance: 30_000, drawn: [0]) == nil)
    #expect(DiveProfileMath.drawnSampleIndex([], at: 10_000, tolerance: 30_000, drawn: []) == nil)
  }

  // MARK: Markers — `dive-profile-chart.tsx:419-439`, `:1473-1558`, `dive-profile.ts:875-992`

  private func marker(_ time: Int, _ type: String?, gas: Int? = nil, label: String? = nil) -> String
  {
    let type = type.map { "\"\($0)\"" } ?? "null"
    let gas = gas.map(String.init) ?? "null"
    let label = label.map { "\"\($0)\"" } ?? "null"
    return #"{"time":\#(time),"type":\#(type),"gas_number":\#(gas),"label":\#(label)}"#
  }

  @Test func markersAreClippedToTheAxisAndDescribed() throws {
    let built = chart(
      try profile(
        duration: 600_000,
        depth: Series(times: [0, 300_000, 600_000], values: [0, 1000, 0]),
        events: [
          marker(-1, "bookmark"), marker(5_000, "gas_switch", gas: 0),
          marker(30_000, "gas_switch", gas: 1), marker(31_000, "gas_switch", gas: 1),
          marker(200_000, "safety_stop_violation"), marker(250_000, nil, label: "  "),
          marker(260_000, "something_new", label: "Low battery"), marker(600_001, "bookmark"),
        ]),
      cylinders: [0, 1])

    #expect(
      built.events.map(\.text) == [
        "Dive started", "Dive started", "Gas switch to tank 2", "Safety stop broken",
        "Device event", "Low battery",
      ])
    #expect(
      built.events.map(\.glyph) == [.diamond, .diamond, .diamond, .triangle, .circle, .circle])
    #expect(built.events.map(\.joinsPressure) == [true, true, true, false, false, false])
  }

  @Test func theNearestMarkerIsFoundWithinReach() throws {
    let built = chart(
      try profile(
        duration: 3_000_000,
        depth: Series(times: [0, 3_000_000], values: [0, 0]),
        events: [
          marker(0, "gas_switch", gas: 0), marker(497_000, nil, label: "NoDecoTime"),
          marker(2_075_000, "gas_switch", gas: 1),
        ]))
    #expect(built.event(near: 480_000, within: 40_000)?.text == "NoDecoTime")
    #expect(built.event(near: 1_280_000, within: 40_000) == nil)
    #expect(built.event(near: 300_000, within: 600_000)?.time == 497_000)
    #expect(built.event(near: 200_000, within: 600_000)?.time == 0)
  }

  @Test func aTieGoesToTheEarlierMarker() throws {
    let built = chart(
      try profile(
        duration: 300_000, depth: Series(times: [0, 300_000], values: [0, 0]),
        events: [marker(200_000, "bookmark"), marker(100_000, "bookmark")]))
    #expect(built.event(near: 150_000, within: 60_000)?.time == 100_000)
  }

  // MARK: Time axis and summary

  @Test func timeTicksThinOnANarrowPlot() throws {
    let built = chart(
      try profile(duration: 3_600_000, depth: Series(times: [0, 3_600_000], values: [0, 0])))
    #expect(
      built.timeTicks(plotWidth: 600).map(\.text) == [
        "0:00", "10:00", "20:00", "30:00", "40:00", "50:00", "60:00",
      ])
    #expect(built.timeTicks(plotWidth: 140).map(\.text) == ["0:00", "30:00", "60:00"])
  }

  @Test func theSummarySaysWhatIsShown() throws {
    let built = chart(
      try profile(
        duration: 600_000,
        depth: Series(times: [0, 300_000, 600_000], values: [0, 1830, 0]),
        temperature: Series(times: [0, 300_000, 600_000], values: [2160, 2100, 2150]),
        events: [marker(5_000, "gas_switch", gas: 0)]))
    let layout = built.layout(hiding: [.temperature])
    #expect(
      layout.summary(events: built.events)
        == "Dive profile over 10min, maximum depth 18.3 meters, markers: Dive started at 0min.")
  }
}
