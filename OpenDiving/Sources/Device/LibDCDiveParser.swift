@preconcurrency import Clibdivecomputer
import Foundation
import LibDCBridge
import OpenDivingKit

/// One dive's bytes read through libdivecomputer's parser into the Kit's ``ComputerDive``: each
/// field present only where the parser reported it, each sample value on the sample it was
/// reported in, every sensor's ppO₂ and every position kept, the parser's zone kept. Not
/// libdc-swift's `GenericParser`, which drops the zone, fills defaults and carries values
/// forward onto later samples.
nonisolated enum LibDCDiveParser {
  /// What the parser made of one buffer.
  enum Parsed: Hashable, Sendable {
    case dive(ComputerDive)
    /// The parser could not open the buffer, or no start came from it or the fingerprint.
    case refused(start: ComputerDive.Start?)
    /// No samples and no duration: not a dive. On the Nautic family, the Suunto app holding
    /// the link.
    case empty
  }

  /// Reads `bytes` as a dive of `family` / `model`. `logsInstants` says the parser's start is
  /// an instant rather than a wall clock; `fallbackStart` is the start the fingerprint carries,
  /// for a family whose dives may have none in their data.
  static func parse(
    _ bytes: Data, context: OpaquePointer?, family: dc_family_t, model: UInt32,
    logsInstants: Bool, fallbackStart: ComputerDive.Start?
  ) -> Parsed {
    var parser: OpaquePointer?
    let status = bytes.withUnsafeBytes { buffer in
      create_parser_for_device(
        &parser, context, family, model,
        buffer.bindMemory(to: UInt8.self).baseAddress, buffer.count)
    }
    guard status == DC_STATUS_SUCCESS, let parser else {
      return .refused(start: fallbackStart)
    }
    defer { dc_parser_destroy(parser) }

    guard let start = start(parser, logsInstants: logsInstants) ?? fallbackStart else {
      return .refused(start: nil)
    }
    var dive = fields(parser, start: start)
    var accumulator = SampleAccumulator()
    withUnsafeMutablePointer(to: &accumulator) { pointer in
      // A walk that fails part-way keeps the samples delivered before it.
      _ = dc_parser_samples_foreach(parser, sampleCallback, pointer)
    }
    dive.samples = accumulator.finish()
    if dive.samples.isEmpty, (dive.diveTime ?? 0) <= 1 { return .empty }
    return .dive(dive)
  }

  /// The start as the parser reported it: an instant for a family that logs them, else the
  /// wall clock with its offset where the parser reported a zone.
  static func start(_ parser: OpaquePointer, logsInstants: Bool) -> ComputerDive.Start? {
    var datetime = dc_datetime_t()
    guard dc_parser_get_datetime(parser, &datetime) == DC_STATUS_SUCCESS else { return nil }
    return start(datetime, logsInstants: logsInstants)
  }

  static func start(_ datetime: dc_datetime_t, logsInstants: Bool) -> ComputerDive.Start? {
    // INT_MIN is `DC_TIMEZONE_NONE`, a macro Swift does not import.
    let offset: Int? = datetime.timezone == Int32.min ? nil : Int(datetime.timezone)
    if logsInstants {
      var utc = Calendar(identifier: .gregorian)
      utc.timeZone = TimeZone(secondsFromGMT: 0)!
      let components = DateComponents(
        year: Int(datetime.year), month: Int(datetime.month), day: Int(datetime.day),
        hour: Int(datetime.hour), minute: Int(datetime.minute), second: Int(datetime.second))
      guard let clock = utc.date(from: components) else { return nil }
      return .instant(clock.addingTimeInterval(-TimeInterval(offset ?? 0)))
    }
    guard
      let date = CalendarDate(
        year: Int(datetime.year), month: Int(datetime.month), day: Int(datetime.day)),
      let clock = LocalDateTime(
        date: date, hour: Int(datetime.hour), minute: Int(datetime.minute),
        second: Int(datetime.second))
    else { return nil }
    return .wallClock(clock, utcOffsetSeconds: offset)
  }

  /// A Nautic dive's fingerprint is its start as little-endian Unix seconds.
  static func fingerprintStart(_ fingerprint: Data) -> ComputerDive.Start? {
    guard fingerprint.count == 4 else { return nil }
    let seconds = fingerprint.reversed().reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
    return .instant(Date(timeIntervalSince1970: TimeInterval(seconds)))
  }

  // MARK: - Fields

  private static func fields(_ parser: OpaquePointer, start: ComputerDive.Start) -> ComputerDive {
    var dive = ComputerDive(start: start)
    dive.diveTime = field(parser, DC_FIELD_DIVETIME, as: UInt32.self).map(Int.init)
    dive.maxDepth = field(parser, DC_FIELD_MAXDEPTH, as: Double.self)
    dive.averageDepth = field(parser, DC_FIELD_AVGDEPTH, as: Double.self)
    dive.surfaceTemperature = field(parser, DC_FIELD_TEMPERATURE_SURFACE, as: Double.self)
    dive.minimumTemperature = field(parser, DC_FIELD_TEMPERATURE_MINIMUM, as: Double.self)
    dive.maximumTemperature = field(parser, DC_FIELD_TEMPERATURE_MAXIMUM, as: Double.self)
    dive.atmosphericPressure = field(parser, DC_FIELD_ATMOSPHERIC, as: Double.self)

    let mixes = field(parser, DC_FIELD_GASMIX_COUNT, as: UInt32.self) ?? 0
    dive.gasMixes = (0..<mixes).compactMap { index in
      field(parser, DC_FIELD_GASMIX, flags: index, as: dc_gasmix_t.self).map(gasMix)
    }
    let tanks = field(parser, DC_FIELD_TANK_COUNT, as: UInt32.self) ?? 0
    dive.tanks = (0..<tanks).compactMap { index in
      field(parser, DC_FIELD_TANK, flags: index, as: dc_tank_t.self).map(tank)
    }
    dive.mode = field(parser, DC_FIELD_DIVEMODE, as: dc_divemode_t.self).flatMap(mode)
    dive.decoModel = field(parser, DC_FIELD_DECOMODEL, as: dc_decomodel_t.self).map(decoModel)
    dive.salinity = field(parser, DC_FIELD_SALINITY, as: dc_salinity_t.self).map(salinity)
    dive.location = field(parser, DC_FIELD_LOCATION, as: dc_location_t.self).map(location)
    return dive
  }

  /// A field the parser reported; nil for `DC_STATUS_UNSUPPORTED` and any other failure.
  private static func field<Value>(
    _ parser: OpaquePointer, _ type: dc_field_type_t, flags: UInt32 = 0, as: Value.Type
  ) -> Value? {
    let pointer = UnsafeMutableRawPointer.allocate(
      byteCount: MemoryLayout<Value>.size, alignment: MemoryLayout<Value>.alignment)
    defer { pointer.deallocate() }
    memset(pointer, 0, MemoryLayout<Value>.size)
    guard dc_parser_get_field(parser, type, flags, pointer) == DC_STATUS_SUCCESS else {
      return nil
    }
    return pointer.load(as: Value.self)
  }

  static func gasMix(_ mix: dc_gasmix_t) -> ComputerDive.GasMix {
    ComputerDive.GasMix(oxygen: mix.oxygen, helium: mix.helium, usage: usage(mix.usage))
  }

  static func tank(_ tank: dc_tank_t) -> ComputerDive.Tank {
    let hasVolume = tank.type != DC_TANKVOLUME_NONE
    return ComputerDive.Tank(
      gasMix: tank.gasmix == DC_GASMIX_UNKNOWN ? nil : Int(tank.gasmix),
      volumeType: tank.type == DC_TANKVOLUME_METRIC
        ? .metric : tank.type == DC_TANKVOLUME_IMPERIAL ? .imperial : nil,
      volume: hasVolume ? tank.volume : nil,
      workingPressure: hasVolume && tank.workpressure != 0 ? tank.workpressure : nil,
      beginPressure: tank.beginpressure, endPressure: tank.endpressure,
      usage: usage(tank.usage))
  }

  static func mode(_ mode: dc_divemode_t) -> ComputerDive.Mode? {
    switch mode {
    case DC_DIVEMODE_FREEDIVE: .freedive
    case DC_DIVEMODE_GAUGE: .gauge
    case DC_DIVEMODE_OC: .openCircuit
    case DC_DIVEMODE_CCR: .closedCircuit
    case DC_DIVEMODE_SCR: .semiClosed
    default: nil
    }
  }

  static func decoModel(_ model: dc_decomodel_t) -> ComputerDive.DecoModel {
    let kind: ComputerDive.DecoModel.Kind =
      switch model.type {
      case DC_DECOMODEL_BUHLMANN: .buhlmann
      case DC_DECOMODEL_VPM: .vpm
      case DC_DECOMODEL_RGBM: .rgbm
      case DC_DECOMODEL_DCIEM: .dciem
      default: .none
      }
    let low = Int(model.params.gf.low)
    let high = Int(model.params.gf.high)
    // 0/0 is libdivecomputer's "not available".
    let factors =
      kind == .buhlmann && (low != 0 || high != 0)
      ? ComputerDive.DecoModel.GradientFactors(low: low, high: high) : nil
    return ComputerDive.DecoModel(
      kind: kind, conservatism: Int(model.conservatism), gradientFactors: factors)
  }

  static func salinity(_ salinity: dc_salinity_t) -> ComputerDive.Salinity {
    ComputerDive.Salinity(
      water: salinity.type == DC_WATER_FRESH ? .fresh : .salt,
      density: salinity.density > 0 ? salinity.density : nil)
  }

  static func location(_ location: dc_location_t) -> ComputerDive.Location {
    ComputerDive.Location(
      latitude: location.latitude, longitude: location.longitude,
      altitude: location.altitude.isFinite ? location.altitude : nil)
  }

  static func usage(_ usage: dc_usage_t) -> ComputerDive.Usage? {
    switch usage {
    case DC_USAGE_OXYGEN: .oxygen
    case DC_USAGE_DILUENT: .diluent
    case DC_USAGE_SIDEMOUNT: .sidemount
    default: nil
    }
  }
}

private nonisolated let sampleCallback: dc_sample_callback_t = { type, value, userdata in
  guard let value, let userdata else { return }
  userdata.assumingMemoryBound(to: SampleAccumulator.self).pointee.add(type, value.pointee)
}
