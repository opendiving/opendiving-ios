import Clibdivecomputer
import Foundation
import OpenDivingKit
import Testing

@testable import OpenDiving

/// The parser's pieces over values written by hand: samples as libdivecomputer's callback
/// reports them, the start, and the absences a successful field reports.
struct LibDCDiveParserTests {
  private func value(_ set: (inout dc_sample_value_t) -> Void) -> dc_sample_value_t {
    var value = dc_sample_value_t()
    set(&value)
    return value
  }

  @Test func eachValueLandsOnTheSampleItWasReportedIn() {
    var accumulator = SampleAccumulator()
    accumulator.add(DC_SAMPLE_TIME, value { $0.time = 0 })
    accumulator.add(DC_SAMPLE_DEPTH, value { $0.depth = 1.5 })
    accumulator.add(DC_SAMPLE_TEMPERATURE, value { $0.temperature = 27.25 })
    accumulator.add(
      DC_SAMPLE_PPO2,
      value {
        $0.ppo2.sensor = 0
        $0.ppo2.value = 1.1
      })
    accumulator.add(
      DC_SAMPLE_PPO2,
      value {
        $0.ppo2.sensor = DC_SENSOR_NONE
        $0.ppo2.value = 1.2
      })
    accumulator.add(DC_SAMPLE_TIME, value { $0.time = 10_000 })
    accumulator.add(DC_SAMPLE_DEPTH, value { $0.depth = 4 })
    accumulator.add(
      DC_SAMPLE_DECO,
      value {
        $0.deco.type = DC_DECO_DECOSTOP.rawValue
        $0.deco.depth = 3
        $0.deco.time = 60
        $0.deco.tts = 120
      })
    accumulator.add(
      DC_SAMPLE_PRESSURE,
      value {
        $0.pressure.tank = 1
        $0.pressure.value = 180
      })
    let samples = accumulator.finish()

    #expect(samples.count == 2)
    #expect(samples[0].time == 0)
    #expect(samples[0].depth == 1.5)
    #expect(samples[0].temperature == 27.25)
    #expect(samples[0].ppo2 == [.init(sensor: 0, bar: 1.1), .init(sensor: nil, bar: 1.2)])
    #expect(samples[0].deco == nil)
    #expect(samples[1].time == 10_000)
    #expect(samples[1].temperature == nil, "nothing is carried forward")
    #expect(samples[1].deco == .init(kind: .decoStop, time: 60, depth: 3, timeToSurface: 120))
    #expect(samples[1].pressures == [.init(tank: 1, bar: 180)])
  }

  @Test func eventsVendorRecordsAndPositionsAreKept() throws {
    var accumulator = SampleAccumulator()
    let bytes: [UInt8] = [1, 2, 3]
    bytes.withUnsafeBufferPointer { buffer in
      accumulator.add(DC_SAMPLE_TIME, value { $0.time = 2_000 })
      accumulator.add(
        DC_SAMPLE_EVENT,
        value {
          $0.event.type = SAMPLE_EVENT_BOOKMARK.rawValue
          $0.event.flags = SAMPLE_FLAGS_BEGIN.rawValue
          $0.event.value = 7
        })
      accumulator.add(
        DC_SAMPLE_VENDOR,
        value {
          $0.vendor.type = 6
          $0.vendor.size = 3
          $0.vendor.data = UnsafeRawPointer(buffer.baseAddress)
        })
      accumulator.add(
        DC_SAMPLE_LOCATION,
        value {
          $0.location.latitude = 27.9
          $0.location.longitude = 34.3
          $0.location.altitude = 0
        })
      accumulator.add(DC_SAMPLE_GASMIX, value { $0.gasmix = DC_GASMIX_UNKNOWN })
    }
    let samples = accumulator.finish()
    #expect(samples.count == 1)
    let sample = try #require(samples.first)
    #expect(sample.events == [.init(type: 8, time: 0, flags: 1, value: 7)])
    #expect(sample.vendor == [.init(type: 6, bytes: Data([1, 2, 3]))])
    #expect(sample.location == .init(latitude: 27.9, longitude: 34.3, altitude: 0))
    #expect(sample.gasMix == nil)
  }

  @Test func aWallClockKeepsTheZoneTheParserReported() {
    var datetime = dc_datetime_t(
      year: 2026, month: 10, day: 25, hour: 9, minute: 14, second: 5, timezone: Int32.min)
    let naive = LibDCDiveParser.start(datetime, logsInstants: false)
    let clock = LocalDateTime(
      date: CalendarDate(year: 2026, month: 10, day: 25)!, hour: 9, minute: 14, second: 5)!
    #expect(naive == .wallClock(clock, utcOffsetSeconds: nil))
    datetime.timezone = 7200
    #expect(
      LibDCDiveParser.start(datetime, logsInstants: false)
        == .wallClock(clock, utcOffsetSeconds: 7200))
  }

  @Test func anInstantIsTheMomentTheParserReported() {
    let datetime = dc_datetime_t(
      year: 2026, month: 10, day: 25, hour: 6, minute: 14, second: 0, timezone: 0)
    #expect(
      LibDCDiveParser.start(datetime, logsInstants: true)
        == .instant(Date(timeIntervalSince1970: 1_792_908_840)))
  }

  @Test func aNauticFingerprintIsItsStart() {
    let fingerprint = Data([0x28, 0x7B, 0xDD, 0x6A])
    #expect(
      LibDCDiveParser.fingerprintStart(fingerprint)
        == .instant(Date(timeIntervalSince1970: 0x6ADD_7B28)))
    #expect(LibDCDiveParser.fingerprintStart(Data([1, 2])) == nil)
  }

  @Test func absencesInsideAFieldAreAbsent() {
    var tank = dc_tank_t()
    tank.gasmix = DC_GASMIX_UNKNOWN
    tank.type = DC_TANKVOLUME_NONE
    tank.beginpressure = 200
    tank.endpressure = 50
    let read = LibDCDiveParser.tank(tank)
    #expect(read.gasMix == nil)
    #expect(read.volume == nil)
    #expect(read.workingPressure == nil)
    #expect(read.beginPressure == 200)

    var model = dc_decomodel_t()
    model.type = DC_DECOMODEL_BUHLMANN
    #expect(LibDCDiveParser.decoModel(model).gradientFactors == nil)
    model.params.gf.low = 40
    model.params.gf.high = 85
    #expect(LibDCDiveParser.decoModel(model).gradientFactors == .init(low: 40, high: 85))
  }

  @Test func aBufferNoParserOpensIsRefusedWithTheFingerprintsStart() {
    let start = ComputerDive.Start.instant(Date(timeIntervalSince1970: 1_792_908_840))
    let parsed = LibDCDiveParser.parse(
      Data([0, 1, 2]), context: nil, family: DC_FAMILY_NULL, model: 0, logsInstants: true,
      fallbackStart: start)
    #expect(parsed == .refused(start: start))
  }
}
