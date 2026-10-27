import Foundation
import OpenDivingKit

/// The downloads the writer's goldens and the model's tests are made from, written by hand from
/// what libdivecomputer's Shearwater and Suunto Nautic parsers report.
enum DiveComputerFixtures {
  static let perdix = DiveComputerIdentity(
    family: .shearwaterPetrel, vendor: "Shearwater", product: "Perdix 3", serial: "D9772626",
    firmware: "93", familyNumber: 0x0003_0000 | 2, modelNumber: 14)

  static let ocean = DiveComputerIdentity(
    family: .suuntoNautic, vendor: "Suunto", product: "Ocean", serial: "253810000400",
    firmware: "2.4.6", familyNumber: 25 << 16, modelNumber: 1)

  static let perdixFound = FoundComputer(
    id: UUID(uuidString: "6f0c7c1e-2b3a-4d5e-8f90-a1b2c3d4e5f6")!, name: "Perdix 3",
    family: .shearwaterPetrel, vendor: "Shearwater", product: "Perdix 3", modelNumber: 14)

  static let oceanFound = FoundComputer(
    id: UUID(uuidString: "0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d")!,
    name: "Suunto Ocean 253810000400", family: .suuntoNautic, vendor: "Suunto",
    product: "Ocean", modelNumber: 1)

  static let helsinki = TimeZone(identifier: "Europe/Helsinki")!
  /// 2026-10-25 09:20 in Helsinki: the download's moment.
  static let moment = Date(timeIntervalSince1970: 1_792_912_800)

  static func clock(_ text: String) -> LocalDateTime {
    guard case .wallClock(let clock)? = DiveTimestamp(wireValue: text) else {
      fatalError("not a wall clock: \(text)")
    }
    return clock
  }

  static func fingerprint(_ byte: UInt8) -> Data { Data([byte, 0xA0, 0x0B, 0xCD]) }

  /// The Perdix 3's newest dive, with something on every channel the writer maps.
  static var perdixDive: ComputerDive {
    var dive = ComputerDive(
      start: .wallClock(clock("2026-10-25T09:14:07"), utcOffsetSeconds: nil))
    dive.diveTime = 3730
    dive.maxDepth = 30.52
    dive.averageDepth = 14.213
    dive.surfaceTemperature = 26
    dive.minimumTemperature = 24.5
    dive.maximumTemperature = 27.1
    dive.gasMixes = [
      .init(oxygen: 0.21, helium: 0), .init(oxygen: 0.5, helium: 0, usage: .oxygen),
    ]
    dive.tanks = [
      .init(
        gasMix: 0, volumeType: .metric, volume: 11.1, workingPressure: 232, beginPressure: 200.5,
        endPressure: 60.2)
    ]
    dive.mode = .openCircuit
    dive.decoModel = .init(kind: .buhlmann, gradientFactors: .init(low: 40, high: 85))
    dive.salinity = .init(water: .salt, density: 1020)
    dive.atmosphericPressure = 1.013

    var first = ComputerDive.Sample(time: 0, depth: 0.4, temperature: 26.4)
    first.pressures = [.init(tank: 0, bar: 200.5)]
    first.gasMix = 0
    first.deco = .init(kind: .ndl, time: 5940, depth: 0)
    first.ppo2 = [.init(sensor: nil, bar: 0.22)]
    first.cns = 0.02
    var second = ComputerDive.Sample(time: 10_000, depth: 18.25, temperature: 25.12)
    second.pressures = [.init(tank: 0, bar: 190.1)]
    second.deco = .init(kind: .decoStop, time: 60, depth: 3, timeToSurface: 240)
    second.ppo2 = [
      .init(sensor: nil, bar: 0.6), .init(sensor: 0, bar: 0.61), .init(sensor: 1, bar: 0.59),
    ]
    second.setpoint = 1.3
    second.heartRate = 92
    second.bearing = 270
    second.remainingBottomTime = 41
    second.events = [.init(type: 8), .init(type: 16, time: 3, flags: 1, value: 7)]
    var third = ComputerDive.Sample(time: 20_000, depth: 5.01)
    third.gasMix = 1
    third.deco = .init(kind: .safetyStop, time: 180, depth: 5)
    third.events = [.init(type: 12, flags: 1)]
    var repeated = ComputerDive.Sample(time: 20_000, depth: 4.9)
    repeated.location = .init(latitude: 28.5, longitude: 34.52, altitude: 2)
    dive.samples = [first, second, third, repeated]
    return dive
  }

  /// A Teric-style log that reports its zone, and nothing else but its depth.
  static var tericStyleDive: ComputerDive {
    var dive = ComputerDive(
      start: .wallClock(clock("2026-10-24T15:02:00"), utcOffsetSeconds: 3 * 3600))
    dive.diveTime = 1800
    dive.maxDepth = 12
    dive.samples = [.init(time: 0, depth: 0.5), .init(time: 10_000, depth: 12)]
    return dive
  }

  static var perdixDownload: [DownloadedDive] {
    [
      DownloadedDive(
        identity: perdix, fingerprint: fingerprint(3), bytes: Data("perdix dive 3".utf8),
        reading: .dive(perdixDive)),
      DownloadedDive(
        identity: perdix, fingerprint: fingerprint(2), bytes: Data("perdix dive 2".utf8),
        reading: .dive(tericStyleDive)),
      DownloadedDive(
        identity: perdix, fingerprint: fingerprint(1), bytes: Data("perdix dive 1".utf8),
        reading: .refused(start: nil)),
    ]
  }

  /// Two Ocean dives either side of the night Helsinki leaves summer time, as instants.
  static var oceanDownload: [DownloadedDive] {
    var after = ComputerDive(start: .instant(Date(timeIntervalSince1970: 1_793_008_800)))
    after.diveTime = 2400
    after.maxDepth = 21.3
    after.mode = .openCircuit
    after.decoModel = .init(kind: .rgbm, conservatism: -1)
    after.salinity = .init(water: .salt, density: 1025)
    after.location = .init(latitude: 60.15, longitude: 24.95)
    after.samples = [
      .init(time: 0, depth: 0.3, temperature: 9.5), .init(time: 1000, depth: 1.2),
    ]
    var before = ComputerDive(start: .instant(Date(timeIntervalSince1970: 1_792_836_000)))
    before.diveTime = 3000
    before.maxDepth = 18
    before.decoModel = .init(kind: .vpm, conservatism: 2)
    return [
      DownloadedDive(
        identity: ocean, fingerprint: fingerprint(0x12), bytes: Data("ocean after".utf8),
        reading: .dive(after)),
      DownloadedDive(
        identity: ocean, fingerprint: fingerprint(0x11), bytes: Data("ocean before".utf8),
        reading: .dive(before)),
    ]
  }

  static let generator = ComputerArchiveWriter.Generator(
    name: "OpenDiving for iOS", version: "0.3.0")
}
