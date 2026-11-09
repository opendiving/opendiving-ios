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
    + #""weather":{"model":"best_match","air_temperature":24.4,"wind_speed":5.9,"#
    + #""wind_direction":45,"weather_code":2}}"#

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
    #expect(metric.windSpeed == "21 km/h")
    #expect(metric.windHeading == 225)
    #expect(
      metric.accessibilityLabel
        == "Partly cloudy, 24 degrees Celsius, wind from the northeast, 21 kilometers per hour")
    #expect(metric.attribution == "[Open-Meteo](https://open-meteo.com/)")

    let imperial = try #require(MapWeatherContent(read, units: .imperial))
    #expect(imperial.temperature == "76°F")
    #expect(imperial.windSpeed == "13 mph")
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
    #expect(content.windSpeed == "0 km/h")
    #expect(content.windHeading == 170)
    #expect(content.accessibilityLabel == "Wind from the north, 0 kilometers per hour")
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
    let model = model(world)
    await model.show(MapWeatherModel.Cell(latitude: 28.5, longitude: 34.5))
    #expect(model.current != nil)
    await model.show(MapWeatherModel.Cell(latitude: 27.9, longitude: 34.3))
    #expect(model.current == nil)
    // A 503 says nothing about the instance: the next cell is asked about.
    await model.show(MapWeatherModel.Cell(latitude: 27.8, longitude: 34.3))
    #expect(asked.all.count == 3)
  }
}
