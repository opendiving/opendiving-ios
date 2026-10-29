import OpenDivingKit
import Testing

/// Transcribed from `src/lib/chart-scale.test.ts` and the domain cases of
/// `src/lib/dive-profile.test.ts` at `opendiving-web` `50c8ce78`; each test names the lines
/// it came from.
struct AxisDomainTests {
  private func domain(_ min: Double, _ max: Double, _ step: Double) -> AxisDomain {
    AxisDomain(min: min, max: max, step: step)
  }

  // MARK: niceDomain — `chart-scale.test.ts:17-48`

  @Test func coversATypicalSpreadWithAReadableStep() {
    #expect(AxisDomain.nice([5.03, 12.67, 25.94]) == domain(5, 30, 5))
  }

  @Test func containsEveryValue() {
    let values = [8.2, 19.9, 13.4, 22.1]
    let nice = AxisDomain.nice(values)
    #expect(nice.min <= values.min()! && nice.max >= values.max()!)
  }

  @Test func isNotAnchoredAtZero() {
    #expect(AxisDomain.nice([18, 19, 20]).min > 0)
  }

  @Test func givesAFlatSeriesABand() {
    #expect(AxisDomain.nice([14, 14, 14]) == domain(13, 15, 1))
  }

  @Test func survivesAnEmptySeries() {
    #expect(AxisDomain.nice([]) == domain(0, 1, 1))
  }

  // MARK: alignedDomain — `chart-scale.test.ts:50-83`

  @Test func coversTheValuesInExactlyTheStepsAskedFor() {
    #expect(AxisDomain.aligned([46.11, 199.06], steps: 4) == domain(0, 200, 50))
  }

  @Test func goesCoarserRatherThanBreakTheCount() {
    let aligned = AxisDomain.aligned([650, 2900], steps: 4)
    #expect(aligned == domain(0, 4000, 1000))
    #expect(aligned.stepCount == 4)
  }

  @Test func givesUnchangingValuesWholeUnitsAround() {
    #expect(AxisDomain.aligned([200, 200], steps: 4) == domain(198, 202, 1))
  }

  @Test func landsEveryTickOnAnotherAxissHeight() {
    let temperature = AxisDomain.nice([21.6, 26.4])
    let pressure = AxisDomain.aligned([30, 210], steps: temperature.stepCount)
    #expect(pressure.ticks.count == temperature.ticks.count)
  }

  // MARK: axisTicks — `chart-scale.test.ts:85-96`

  @Test func ticksIncludeBothEnds() {
    #expect(domain(5, 30, 5).ticks == [5, 10, 15, 20, 25, 30])
  }

  @Test func ticksDoNotDrift() {
    #expect(domain(10, 15, 2.5).ticks == [10, 12.5, 15])
  }

  /// `dive-profile-chart.tsx:1133-1136` — a ppO₂ row counted in fifths of a bar, whose
  /// third tick is `0.6000000000000001` before it settles.
  @Test func aPpo2RowReadsItsOwnNumbers() {
    let row = ProfileAxis.ppo2.domain([0.21, 0.98])
    #expect(row.ticks.map(NumberText.plain) == ["0.2", "0.4", "0.6", "0.8", "1"])
  }

  // MARK: labelCapacity — `chart-scale.test.ts:163-171`

  @Test func labelCapacityCountsWholeLabels() {
    #expect(AxisDomain.labelCapacity(664, spacing: 33) == 20)
    #expect(AxisDomain.labelCapacity(10, spacing: 33) == 1)
  }

  // MARK: depthDomain — `dive-profile.test.ts:340-367`

  @Test func depthIsAnchoredAtTheSurface() {
    #expect(ProfileAxis.depthDomain(depth: [12.4, 38.2, 4.1], ceiling: []).min == 0)
  }

  @Test func depthIsOneAxisWithTheCeiling() {
    let both = ProfileAxis.depthDomain(depth: [12.4, 38.2], ceiling: [3, 6.5])
    #expect(both == ProfileAxis.depthDomain(depth: [12.4, 38.2], ceiling: []))
    let ceilingOnly = ProfileAxis.depthDomain(depth: [], ceiling: [3, 12.65])
    #expect(ceilingOnly.min == 0 && ceilingOnly.max >= 12.65)
  }

  // MARK: axisDomain — `dive-profile.test.ts:369-432`

  /// The owner's Suunto Ocean `gf99` fault.
  private let suuntoGf99Peak = 14_060.0

  @Test func fitsAnUnboundedAxisToItsReadings() {
    #expect(ProfileAxis.timeToSurface.domain([0, 18, 900]) == AxisDomain.nice([0, 18, 900]))
  }

  @Test func leavesAPercentAxisAloneUnderTheBound() {
    let readings = [0.0, 30, 84, 121]
    #expect(ProfileAxis.percent.domain(readings) == AxisDomain.nice(readings))
    #expect(ProfileAxis.percent.domain(readings).max < 200)
  }

  @Test func stopsAPercentAxisAt200() {
    #expect(ProfileAxis.percent.domain([0, 170, suuntoGf99Peak]) == domain(0, 200, 50))
    #expect(
      ProfileAxis.percent.domain([0, 170, 400])
        == ProfileAxis.percent.domain([0, 170, suuntoGf99Peak]))
    #expect(ProfileAxis.percent.domain([732, suuntoGf99Peak]) == domain(0, 200, 50))
  }

  // MARK: temperatureDomain — `dive-profile.test.ts:434-462`

  @Test func widensBarelyMovingWaterToTwoDegrees() {
    #expect(
      ProfileAxis.temperatureDomain([27.1, 26.9, 26.7], units: .metric) == domain(25.5, 28, 0.5))
  }

  @Test func fitsAWideTemperatureSpanAsNiceDoes() {
    let readings = [18.2, 21.4, 24.6]
    #expect(ProfileAxis.temperatureDomain(readings, units: .metric) == AxisDomain.nice(readings))
  }

  @Test func measuresTheTwoDegreesInTheDiversUnits() {
    let fahrenheit = ProfileAxis.temperatureDomain([80.1, 80.8], units: .imperial)
    #expect(fahrenheit.max - fahrenheit.min >= 3.6)
    #expect(fahrenheit.min <= 80.1 && fahrenheit.max >= 80.8)
    #expect(ProfileAxis.temperatureDomain([], units: .metric) == AxisDomain.nice([]))
  }

  // MARK: axisUnitSuffix and channelsOnAxis — `dive-profile.test.ts:1239-1289`

  @Test func panelSuffixesCarryTheSeparator() {
    #expect(ProfileAxis.noDeco.unitSuffix(.metric) == " min")
    #expect(ProfileAxis.timeToSurface.unitSuffix(.metric) == " min")
    #expect(ProfileAxis.ppo2.unitSuffix(.metric) == " bar")
    #expect(ProfileAxis.percent.unitSuffix(.metric) == "%")
    #expect(ProfileAxis.heartRate.unitSuffix(.imperial) == " bpm")
    #expect(ProfileAxis.depth.unitSuffix(.imperial) == " ft")
    #expect(ProfileAxis.percent.unitSuffix(.imperial) == "%")
  }

  @Test func noDecoAndTimeToSurfaceAreTwoAxes() {
    #expect(ProfileAxis.noDeco.channels == [.ndl])
    #expect(ProfileAxis.timeToSurface.channels == [.tts])
    #expect(ProfileAxis.ppo2.channels == [.ppo2])
    #expect(ProfileAxis.pressure.channels == [.pressure])
    #expect(ProfileAxis.heartRate.channels == [.heartRate])
    #expect(ProfileAxis.percent.channels == [.cns, .surfaceGradientFactor, .gradientFactor])
    #expect(ProfileAxis.depth.channels == [.depth, .ceiling])
  }
}
