import Foundation
import Synchronization
import Testing

@testable import OpenDivingKit

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// The Sites map's weather bar: what it says of an answer, and when it asks.
@MainActor
@Suite(.serialized)
struct MapWeatherTests {
  private static let dahab =
    #"{"provider":"open-meteo","attribution":"[Open-Meteo](https://open-meteo.com/)","#
    + #""at":"2026-11-09T14:00:00+02:00","position":{"latitude":28.5,"longitude":34.5},"#
    + #""weather":{"model":"best_match","air_temperature":24.4,"relative_humidity":61.6,"#
    + #""wind_speed":5.9,"wind_direction":45,"wind_gusts":8.3,"cloud_cover":40,"#
    + #""precipitation":0.4,"pressure":1012.3,"weather_code":2}}"#

  /// The positions the server was asked about, as `latitude,longitude`.
  final class Asked: Sendable {
    private let sent = Mutex<[String]>([])
    func record(_ url: URL?) {
      let items =
        url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }?
        .queryItems ?? []
      let value = { (name: String) in items.first { $0.name == name }?.value ?? "-" }
      sent.withLock { $0.append("\(value("latitude")),\(value("longitude"))") }
    }
    var all: [String] { sent.withLock { $0 } }
  }

  private func world(_ asked: Asked, answer: StubTransport.Response) async throws -> FormWorld {
    let world = try FormWorld()
    world.server.override { request, _ in
      guard request.route == "GET dive-conditions/current" else { return nil }
      asked.record(request.url)
      return answer
    }
    try await world.session.loadAccount()
    return world
  }

  private func model(_ world: FormWorld) -> MapWeatherModel {
    let model = MapWeatherModel(session: world.session)
    model.settleDelay = .zero
    model.retryDelay = .zero
    return model
  }

  /// A model whose failed ask waits for the test, which pans or brings a route back.
  private func patientModel(_ world: FormWorld) -> MapWeatherModel {
    let model = model(world)
    model.retryDelay = .seconds(3600)
    return model
  }

  private static func read(_ weather: ConditionsWeather?) -> DiveConditionsCurrentRead {
    DiveConditionsCurrentRead(
      attribution: "[Open-Meteo](https://open-meteo.com/)", weather: weather)
  }

  // MARK: - The content

  @Test func theBarShowsTheSkyTheTemperatureAndTheWindTowardWhereItBlows() throws {
    let read = try APICoding.decoder().decode(
      DiveConditionsCurrentRead.self, from: Data(Self.dahab.utf8))
    let metric = try #require(MapWeatherContent(read, units: .metric))
    #expect(metric.icon == .cloudSun)
    #expect(metric.temperature == "24°C")
    #expect(metric.windSpeed == "11 kn")
    #expect(metric.windHeading == 225)
    #expect(metric.summary == "Partly cloudy, 24°C, wind from the northeast, 11 kn")
    #expect(
      metric.accessibilityLabel
        == "Partly cloudy, 24 degrees Celsius, wind from the northeast, 11 knots")
    #expect(metric.attribution == "[Open-Meteo](https://open-meteo.com/)")

    let imperial = try #require(MapWeatherContent(read, units: .imperial))
    #expect(imperial.temperature == "76°F")
    #expect(imperial.windSpeed == "11 kn")
  }

  @Test func theTapListsTheRestOfTheReadingInTheDiversUnits() throws {
    let read = try APICoding.decoder().decode(
      DiveConditionsCurrentRead.self, from: Data(Self.dahab.utf8))
    let metric = try #require(MapWeatherContent(read, units: .metric))
    #expect(
      metric.details.map(\.label) == [
        "Gusts", "Cloud cover", "Rain, last hour", "Humidity", "Pressure",
      ])
    #expect(metric.details.map(\.value) == ["16 kn", "40%", "0.4 mm", "62%", "1012 hPa"])
    #expect(
      metric.details.map(\.spokenValue) == [
        "16 knots", "40 percent", "0.4 millimeters", "62 percent", "1012 hectopascals",
      ])

    let imperial = try #require(MapWeatherContent(read, units: .imperial))
    #expect(imperial.details.map(\.value) == ["16 kn", "40%", "0.02 in", "62%", "1012 hPa"])
    #expect(imperial.details[2].spokenValue == "0.02 inches")
  }

  /// The API's live answer for the Blue Hole: the sea the marine model gives.
  private static let blueHoleSea: String =
    #""sea":{"model":"best_match","sea_level_height":0.33,"tide_state":"falling","#
    + #""previous_extreme":{"kind":"high","at":"2026-11-10T18:00:00+02:00","height":0.33},"#
    + #""next_extreme":{"kind":"low","at":"2026-11-11T01:00:00+02:00","height":-0.27},"#
    + #""sea_surface_temperature":25.5,"wave_height":0.94,"wave_period":3.7,"#
    + #""swell_wave_height":0.1}"#
  /// An hour after the high water, so it lies on the curve between the two turns.
  private static let blueHole: String =
    String(
      dahab.replacingOccurrences(
        of: "2026-11-09T14:00:00+02:00", with: "2026-11-10T19:00:00+02:00"
      ).dropLast()) + "," + blueHoleSea + "}"

  @Test func theTapListsTheSeaWithTheWavesAndTheTideDrawnRatherThanListed() throws {
    let read = try APICoding.decoder().decode(
      DiveConditionsCurrentRead.self, from: Data(Self.blueHole.utf8))
    let metric = try #require(MapWeatherContent(read, units: .metric))
    #expect(metric.sea.map(\.label) == ["Sea temperature"])
    #expect(metric.sea.map(\.value) == ["26°C"])
    #expect(metric.sea.map(\.spokenValue) == ["26 degrees Celsius"])
    #expect(metric.tide != nil)
    let waves = try #require(metric.waves)
    #expect(waves.strips.map(\.label) == ["Waves", "Swell"])
    #expect(waves.strips.map(\.value) == ["0.9 m · 4 s", "0.1 m"])
    #expect(waves.accessibilityLabel == "Waves 0.9 meters every 4 seconds, swell 0.1 meters")

    let imperial = try #require(MapWeatherContent(read, units: .imperial))
    #expect(imperial.sea.map(\.value) == ["78°F"])
    #expect(imperial.waves?.strips.map(\.value) == ["3 ft · 4 s", "0 ft"])
  }

  /// How far a strip's surface strays from its middle, as a fraction of the strip.
  private static func reach(_ strip: WaveProfile.Strip) -> Double {
    strip.points.map { abs($0.y - 0.5) }.max() ?? 0
  }

  @Test func theWavesAndTheSwellShareOneScaleOfAtLeastAMetre() throws {
    let calm = try #require(
      WaveProfile(
        ConditionsSea(waveHeight: 0.94, wavePeriod: 3.7, swellWaveHeight: 0.1), units: .metric))
    // Crest to trough over a metre-tall strip, eight tenths of which a crest and trough span.
    #expect((0.36...0.376 + 1e-9).contains(Self.reach(calm.strips[0])))
    #expect((0.035...0.04 + 1e-9).contains(Self.reach(calm.strips[1])))
    #expect(calm.strips.allSatisfy { $0.points.first?.x == 0 && $0.points.last?.x == 1 })

    let rough = try #require(
      WaveProfile(ConditionsSea(waveHeight: 3, wavePeriod: 8, swellWaveHeight: 1.5), units: .metric)
    )
    #expect((0.39...0.4 + 1e-9).contains(Self.reach(rough.strips[0])))
    #expect((0.19...0.2 + 1e-9).contains(Self.reach(rough.strips[1])))
  }

  @Test func aSeaWithNoHeightsDrawsNoWavesAndAPeriodAloneIsListed() throws {
    #expect(WaveProfile(ConditionsSea(seaSurfaceTemperature: 20), units: .metric) == nil)
    let content = try #require(
      MapWeatherContent(
        DiveConditionsCurrentRead(
          attribution: "",
          weather: ConditionsWeather(
            airTemperature: 21, windSpeed: nil, windDirection: nil, weatherCode: nil),
          sea: ConditionsSea(wavePeriod: 6)),
        units: .metric))
    #expect(content.waves == nil)
    #expect(content.sea.map(\.value) == ["6 s"])
  }

  @Test func theTideRunsFromTurnToTurnWithTheHourOnItOnThePlacesClock() throws {
    let read = try APICoding.decoder().decode(
      DiveConditionsCurrentRead.self, from: Data(Self.blueHole.utf8))
    let content = try #require(MapWeatherContent(read, units: .metric))
    let tide = try #require(content.tide)
    let close = { (a: Double, b: Double) in abs(a - b) < 1e-9 }

    #expect(tide.turns.map(\.label) == ["High", "Low"])
    #expect(tide.turns.map(\.clock) == ["18:00", "01:00"])
    // Seven hours between the turns, and a quarter of that past each: 10.5 hours drawn.
    #expect(close(tide.turns[0].x, 1.75 / 10.5))
    #expect(close(tide.turns[1].x, 8.75 / 10.5))
    // High water at the top, low at the bottom, a tenth in from each edge.
    let first = try #require(tide.between.first)
    let last = try #require(tide.between.last)
    #expect(close(first.y, 0.1) && close(last.y, 0.9))
    #expect(close(try #require(tide.before.first).x, 0))
    #expect(close(try #require(tide.after.last).x, 1))
    #expect(tide.before.last == first && tide.after.first == last)

    let now = try #require(tide.now)
    #expect(close(now.x, 2.75 / 10.5))
    #expect(close(now.y, 0.5 - cos(Double.pi / 7) * 0.4))
    #expect(
      tide.accessibilityLabel
        == "Tide: high water at 18:00, low water at 01:00; now 19:00, on the falling tide")
  }

  @Test func withOneTurnTheTideIsListedAndNotDrawn() throws {
    let turn = try #require(DiveTimestamp(wireValue: "2026-11-10T19:20:00+02:00"))
    let content = try #require(
      MapWeatherContent(
        DiveConditionsCurrentRead(
          attribution: "",
          weather: ConditionsWeather(
            airTemperature: 21, windSpeed: nil, windDirection: nil, weatherCode: nil),
          sea: ConditionsSea(
            tideState: "rising",
            nextExtreme: ConditionsExtreme(
              kind: "high", at: turn,
              height: 0.3))),
        units: .metric))
    #expect(content.tide == nil)
    #expect(content.sea.map(\.label) == ["Tide", "Next high"])
    #expect(content.sea.map(\.value) == ["Rising", "19:20"])
  }

  @Test func inlandThereIsNoSea() throws {
    let read = try APICoding.decoder().decode(
      DiveConditionsCurrentRead.self, from: Data(Self.dahab.utf8))
    #expect(try #require(MapWeatherContent(read, units: .metric)).sea.isEmpty)
  }

  @Test func aFigureTheProviderLacksIsLeftOutAndNoRainIsStillSaid() throws {
    let content = try #require(
      MapWeatherContent(
        Self.read(
          ConditionsWeather(
            airTemperature: 21, windSpeed: nil, windDirection: nil, precipitation: 0,
            weatherCode: 0)),
        units: .metric))
    #expect(
      content.details == [
        MapWeatherContent.Detail(
          label: "Rain, last hour", value: "0 mm", spokenValue: "0 millimeters")
      ])
  }

  @Test func aNortherlyBlowsSouthAndACodeTheTableLacksDrawsNoIcon() throws {
    let content = try #require(
      MapWeatherContent(
        Self.read(
          ConditionsWeather(
            airTemperature: nil, windSpeed: 0, windDirection: 350, weatherCode: 4)),
        units: .metric))
    #expect(content.icon == nil)
    #expect(content.temperature == nil)
    #expect(content.windSpeed == "0 kn")
    #expect(content.windHeading == 170)
    #expect(content.summary == "Wind from the north, 0 kn")
    #expect(content.accessibilityLabel == "Wind from the north, 0 knots")
  }

  @Test func nothingToShowIsNoBar() {
    #expect(MapWeatherContent(Self.read(nil), units: .metric) == nil)
    let empty = ConditionsWeather(
      airTemperature: nil, windSpeed: nil, windDirection: 90, weatherCode: nil)
    #expect(MapWeatherContent(Self.read(empty), units: .metric) == nil)
  }

  @Test func everyCodeTheInstanceFillsHasAnIcon() {
    for vocabulary in Set(ConditionsWeather.vocabularyByCode.values) {
      #expect(MapWeatherContent.icons[vocabulary] != nil, "\(vocabulary)")
    }
  }

  // MARK: - The cell

  @Test func theCentreIsAskedAboutToATenthOfADegreeAndNotZoomedOut() {
    let cell = MapWeatherModel.cell(MapCamera(latitude: 28.4963, longitude: 34.5146, zoom: 11))
    #expect(cell == MapWeatherModel.Cell(latitude: 28.5, longitude: 34.5))
    let wrapped = MapWeatherModel.cell(MapCamera(latitude: -8.04, longitude: 245.12, zoom: 9))
    #expect(wrapped == MapWeatherModel.Cell(latitude: -8.0, longitude: -114.9))
    #expect(MapWeatherModel.cell(MapCamera(latitude: 28.5, longitude: 34.5, zoom: 5.9)) == nil)
  }

  // MARK: - Asking

  @Test func aCellIsAskedAboutOnceAndPanningBackCostsNothing() async throws {
    let asked = Asked()
    let world = try await world(asked, answer: .json(Self.dahab))
    let model = model(world)
    let dahab = MapWeatherModel.Cell(latitude: 28.5, longitude: 34.5)
    let sharm = MapWeatherModel.Cell(latitude: 27.9, longitude: 34.3)
    await model.show(dahab)
    #expect(model.current?.weather?.weatherCode == 2)
    await model.show(sharm)
    await model.show(dahab)
    #expect(asked.all == ["28.5,34.5", "27.9,34.3"])
    #expect(model.current != nil)
  }

  @Test func anAnswerIsAskedForAgainOnceItIsAQuarterOfAnHourOld() async throws {
    let asked = Asked()
    let world = try await world(asked, answer: .json(Self.dahab))
    let model = model(world)
    let clock = Mutex(Date(timeIntervalSince1970: 1_800_000_000))
    model.now = { clock.withLock { $0 } }
    let dahab = MapWeatherModel.Cell(latitude: 28.5, longitude: 34.5)
    await model.show(dahab)
    clock.withLock { $0 += 14 * 60 }
    await model.show(dahab)
    clock.withLock { $0 += 2 * 60 }
    await model.show(dahab)
    #expect(asked.all.count == 2)
  }

  @Test func zoomedOutTheBarEmpties() async throws {
    let world = try await world(Asked(), answer: .json(Self.dahab))
    let model = model(world)
    await model.show(MapWeatherModel.Cell(latitude: 28.5, longitude: 34.5))
    await model.show(nil)
    #expect(model.current == nil)
  }

  @Test func withNoRouteTheBarEmptiesAndARouteAppearingAsksAgain() async throws {
    let asked = Asked()
    let world = try await world(asked, answer: .json(Self.dahab))
    let model = patientModel(world)
    await model.show(MapWeatherModel.Cell(latitude: 28.5, longitude: 34.5))
    #expect(model.current != nil)
    #expect(!model.isUnreachable)
    world.route.isRouteAvailable = false
    let asking = Task { await model.show(MapWeatherModel.Cell(latitude: 27.9, longitude: 34.3)) }
    while !model.isUnreachable { await Task.yield() }
    #expect(model.current == nil)
    world.route.isRouteAvailable = true
    model.routeAppeared()
    await asking.value
    #expect(model.current != nil)
    #expect(!model.isUnreachable)
    #expect(asked.all == ["28.5,34.5", "27.9,34.3"])
  }

  @Test func aRequestThatNeverArrivesSaysSoAndZoomingOutClearsIt() async throws {
    let world = try FormWorld()
    world.server.override { request, _ in
      guard request.route == "GET dive-conditions/current" else { return nil }
      throw URLError(.timedOut)
    }
    try await world.session.loadAccount()
    let model = patientModel(world)
    let asking = Task { await model.show(MapWeatherModel.Cell(latitude: 28.5, longitude: 34.5)) }
    while !model.isUnreachable { await Task.yield() }
    #expect(model.current == nil)
    // As a zoom out does: the task asking about the cell is cancelled, and the next shows none.
    asking.cancel()
    await model.show(nil)
    await asking.value
    #expect(!model.isUnreachable)
  }

  @Test func anAnswerForACellPannedAwayFromNeverReachesTheBar() async throws {
    let dahab = Self.dahab
    let sharm = dahab.replacingOccurrences(of: #""weather_code":2"#, with: #""weather_code":0"#)
    let gate = Gate()
    let world = try FormWorld()
    world.server.override { request, _ in
      guard request.route == "GET dive-conditions/current" else { return nil }
      if request.url?.query?.contains("latitude=28.5") == true {
        await gate.pass()
        return .json(dahab)
      }
      return .json(sharm)
    }
    try await world.session.loadAccount()
    let model = model(world)
    // Dahab asked about on a task left running, so only the map no longer showing Dahab keeps
    // its answer off the bar.
    let asking = Task { await model.show(MapWeatherModel.Cell(latitude: 28.5, longitude: 34.5)) }
    await gate.untilArrived()
    await model.show(MapWeatherModel.Cell(latitude: 27.9, longitude: 34.3))
    #expect(model.current?.weather?.weatherCode == 0)
    await gate.open()
    await asking.value
    #expect(model.current?.weather?.weatherCode == 0)
  }

  // MARK: - The place

  private static let reverseDahab =
    #"{"latitude":28.4964,"longitude":34.5146,"location":"Dahab, South Sinai, Egypt","#
    + #""name":"Dahab","attribution":"[OSM](https://osm.org)"}"#

  private func placeWorld(
    _ asked: Asked, reverse: @escaping @Sendable (String) -> StubTransport.Response
  )
    async throws -> FormWorld
  {
    let world = try FormWorld()
    let dahab = Self.dahab
    world.server.override { request, _ in
      switch request.route {
      case "GET dive-conditions/current": return .json(dahab)
      case "GET geocode/reverse":
        asked.record(request.url)
        return reverse(request.url?.query ?? "")
      default: return nil
      }
    }
    try await world.session.loadAccount()
    return world
  }

  @Test func theTapNamesThePlaceOnceACell() async throws {
    let asked = Asked()
    let reverse = Self.reverseDahab
    let world = try await placeWorld(asked) { _ in .json(reverse) }
    let model = model(world)
    await model.show(MapWeatherModel.Cell(latitude: 28.5, longitude: 34.5))
    #expect(model.place == nil)
    await model.lookUpPlace()
    #expect(
      model.place
        == MapWeatherModel.Place(
          title: "Dahab, South Sinai, Egypt", credit: "[OSM](https://osm.org)"))
    await model.lookUpPlace()
    #expect(asked.all.count == 1)
    // Another cell's name never stands over this one's weather.
    await model.show(MapWeatherModel.Cell(latitude: 27.9, longitude: 34.3))
    #expect(model.place == nil)
  }

  @Test func aPlaceWithNoNameOrNoGeocoderIsItsPosition() async throws {
    let asked = Asked()
    let world = try await placeWorld(asked) { query in
      query.contains("lat=27.9") ? StubTransport.Response(status: 204) : .json("null")
    }
    let model = model(world)
    await model.show(MapWeatherModel.Cell(latitude: 27.9, longitude: 34.3))
    await model.lookUpPlace()
    #expect(model.place == MapWeatherModel.Place(title: "27.9, 34.3", credit: nil))
    await model.show(MapWeatherModel.Cell(latitude: 26, longitude: 35))
    await model.lookUpPlace()
    #expect(model.place == MapWeatherModel.Place(title: "26, 35", credit: nil))
    // A position with no name is known; one the geocoder could not be asked about is not.
    await model.show(MapWeatherModel.Cell(latitude: 27.9, longitude: 34.3))
    await model.lookUpPlace()
    await model.show(MapWeatherModel.Cell(latitude: 26, longitude: 35))
    await model.lookUpPlace()
    #expect(asked.all.count == 3)
  }

  @Test func aFirstAskTheServerFailsIsAskedAgainWithNoPanAndNoRouteAppearing() async throws {
    let asked = Asked()
    let failures = Mutex(1)
    let dahab = Self.dahab
    let world = try FormWorld()
    world.server.override { request, _ in
      guard request.route == "GET dive-conditions/current" else { return nil }
      asked.record(request.url)
      let failing = failures.withLock { left in
        defer { left -= 1 }
        return left > 0
      }
      return failing
        ? .json(#"{"detail":"The weather could not be looked up now."}"#, status: 503)
        : .json(dahab)
    }
    try await world.session.loadAccount()
    let model = model(world)
    await model.show(MapWeatherModel.Cell(latitude: 28.5, longitude: 34.5))
    #expect(model.current?.weather?.weatherCode == 2)
    #expect(asked.all == ["28.5,34.5", "28.5,34.5"])
  }

  @Test func anInstanceThatFetchesNoConditionsIsAskedOnce() async throws {
    let asked = Asked()
    let world = try await world(
      asked, answer: .json(#"{"detail":"Not Found"}"#, status: 404))
    let model = model(world)
    await model.show(MapWeatherModel.Cell(latitude: 28.5, longitude: 34.5))
    await model.show(MapWeatherModel.Cell(latitude: 27.9, longitude: 34.3))
    #expect(asked.all == ["28.5,34.5"])
    #expect(model.current == nil)
  }

  @Test func aProviderThatCannotBeAskedLeavesNoOtherCellsWeatherShowing() async throws {
    let asked = Asked()
    let answers = Mutex([StubTransport.Response.json(Self.dahab)])
    let world = try FormWorld()
    world.server.override { request, _ in
      guard request.route == "GET dive-conditions/current" else { return nil }
      asked.record(request.url)
      return answers.withLock { $0.isEmpty ? nil : $0.removeFirst() }
        ?? .json(#"{"detail":"Conditions could not be looked up now."}"#, status: 503)
    }
    try await world.session.loadAccount()
    let model = patientModel(world)
    await model.show(MapWeatherModel.Cell(latitude: 28.5, longitude: 34.5))
    #expect(model.current != nil)
    let sharm = Task { await model.show(MapWeatherModel.Cell(latitude: 27.9, longitude: 34.3)) }
    while model.current != nil { await Task.yield() }
    // The server answered, so the bar says nothing of the connection.
    #expect(!model.isUnreachable)
    // A 503 says nothing about the instance: the next cell is asked about.
    sharm.cancel()
    let next = Task { await model.show(MapWeatherModel.Cell(latitude: 27.8, longitude: 34.3)) }
    while asked.all.count < 3 { await Task.yield() }
    next.cancel()
    await sharm.value
    await next.value
    #expect(asked.all.count == 3)
  }
}
