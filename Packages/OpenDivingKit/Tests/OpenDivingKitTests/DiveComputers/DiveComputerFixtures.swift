import Foundation

@testable import OpenDivingKit

/// The downloads the writer's goldens and the model's tests are made from: dives written by hand
/// in the shape the shared libdivecomputer reader returns them. Each is parsed once: the model's
/// tests read them inside wait loops that run many thousands of times.
enum DiveComputerFixtures {
  /// A file of the shape every computer was kept in before the pairing became the phone's.
  static func writeWholeRecord(_ record: DiveComputerRecord, in folder: URL) throws {
    func fields(_ value: some Encodable) throws -> [String: Any] {
      let object = try JSONSerialization.jsonObject(with: APICoding.encoder().encode(value))
      return object as? [String: Any] ?? [:]
    }
    let whole = try fields(PairedComputer(record)).merging(
      fields(DiveComputerProgress(record))
    ) { first, _ in first }
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try JSONSerialization.data(withJSONObject: whole).write(
      to: folder.appendingPathComponent(record.id))
  }

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

  /// A dive as the reader returns it, from its JSON.
  static func dive(_ json: String, logsInstants: Bool = false, fallbackStart: Date? = nil)
    -> ComputerDive
  {
    guard
      let dive = ComputerDive(
        json: Data(json.utf8), logsInstants: logsInstants, fallbackStart: fallbackStart)
    else { fatalError("not a reader's dive: \(json)") }
    return dive
  }

  /// The Perdix 3's newest dive, with something on every channel the reader writes.
  static let perdixDive: ComputerDive = {
    dive(
      #"{"avg_depth":14.21,"cylinders":[{"end_pressure":60.2,"gas_number":0,"helium":0,"oxygen":21,"#
        + #""start_pressure":200.5,"volume":11.1},{"gas_number":1,"helium":0,"oxygen":50,"#
        + #""role":"oxygen"}],"max_depth":30.52,"recordings":[{"deco_model":{"algorithm":"buhlmann","#
        + #""gf_high":85,"gf_low":40},"mode":"open_circuit","profile":{"ceiling":{"times":[10000],"#
        + #""values":[300]},"cns":{"times":[0],"values":[20]},"depth":{"times":[0,10000,20000],"#
        + #""values":[40,1825,501]},"duration":20000,"events":[{"gas_number":0,"time":0,"#
        + #""type":"gas_switch"},{"time":10000,"type":"bookmark"},{"label":"floor","time":10000},"#
        + #"{"gas_number":1,"time":20000,"type":"gas_switch"},{"time":20000,"type":"safety_stop"}],"#
        + #""heart_rate":{"times":[10000],"values":[92]},"ndl":{"times":[0],"values":[5940]},"#
        + #""ppo2":{"times":[0,10000],"values":[22,60]},"pressures":[{"gas_number":0,"#
        + #""times":[0,10000],"values":[2005,1901]}],"temperature":{"times":[0,10000],"#
        + #""values":[2640,2512]},"tts":{"times":[10000],"values":[240]}},"salinity":"en13319","#
        + #""surface_pressure":1.013}],"started_at":"2026-10-25T09:14:07","submerged_time":3730,"#
        + #""uuid":"0b5bd8d1-4c1e-5d0e-9a4f-2f6f3b1c7e01"}"#)
  }()

  /// A Teric-style log that reports its zone, and nothing else but its depth.
  static let tericStyleDive: ComputerDive = {
    dive(
      #"{"max_depth":12,"recordings":[{"profile":{"depth":{"times":[0,10000],"#
        + #""values":[50,1200]},"duration":10000}}],"started_at":"2026-10-24T15:02:00+03:00","#
        + #""submerged_time":1800,"uuid":"0b5bd8d1-4c1e-5d0e-9a4f-2f6f3b1c7e02"}"#)
  }()

  static let perdixDownload: [DownloadedDive] = {
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
  }()

  /// Two Ocean dives either side of the night Helsinki leaves summer time, as the reader spells
  /// a Nautic start, in UTC; the first with the fallback start the walk passes the family.
  static let oceanDownload: [DownloadedDive] = {
    let after = dive(
      #"{"entry_position":{"latitude":60.15,"longitude":24.95},"max_depth":21.3,"#
        + #""recordings":[{"deco_model":{"algorithm":"rgbm","conservatism":-1},"#
        + #""mode":"open_circuit","profile":{"depth":{"times":[0,1000],"values":[30,120]},"#
        + #""duration":1000,"temperature":{"times":[0],"values":[950]}},"salinity":"salt"}],"#
        + #""started_at":"2026-10-26T10:00:00+00:00","submerged_time":2400,"#
        + #""uuid":"0b5bd8d1-4c1e-5d0e-9a4f-2f6f3b1c7e03"}"#,
      logsInstants: true, fallbackStart: Date(timeIntervalSince1970: 1_793_008_800))
    let before = dive(
      #"{"max_depth":18,"recordings":[{}],"started_at":"2026-10-24T10:00:00+00:00","#
        + #""submerged_time":3000,"uuid":"0b5bd8d1-4c1e-5d0e-9a4f-2f6f3b1c7e04"}"#,
      logsInstants: true, fallbackStart: Date(timeIntervalSince1970: 1_792_836_000))
    return [
      DownloadedDive(
        identity: ocean, fingerprint: fingerprint(0x12), bytes: Data("ocean after".utf8),
        reading: .dive(after)),
      DownloadedDive(
        identity: ocean, fingerprint: fingerprint(0x11), bytes: Data("ocean before".utf8),
        reading: .dive(before)),
    ]
  }()

  static let generator = ComputerArchiveWriter.Generator(
    name: "OpenDiving for iOS", version: "0.3.0")
}
