import Foundation

/// One downloaded dive as a DiveJSON 1.0 `dive` object.
///
/// Only what libdivecomputer reported is written, in the spec's units; nothing is invented —
/// no `number`, no `bottom_temperature`, no `water_type` (§6.4a forbids deriving it from the
/// computer's salinity setting), no zero standing in for a reading the computer did not give.
///
/// **Gas numbers.** The dive's `cylinders` are the computer's tanks in its order, then each gas
/// mix no tank holds; a cylinder's `gas_number` is its place in that list. A pressure series
/// carries its tank's number, and a gas switch the number of the first cylinder holding the mix
/// it switched to.
///
/// **What the spec cannot hold** goes under the recording's `extensions.opendiving`, the one
/// object the writer puts extensions on — the api reads members of its own under that key on
/// the document, a dive and a stored file. The api keeps none of it at import; the original
/// bytes beside the document do. The shape, until a spec version takes the members over:
///
/// - `temperature_surface`, `temperature_minimum`, `temperature_maximum`: °C.
/// - `salinity_density`: kg/m³, the density the computer was set to.
/// - `atmospheric_pressure`: bar, where outside `surface_pressure`'s range.
/// - `deco_model`: `{ model, conservatism, gf_low, gf_high }` for a model the spec has no
///   algorithm for (`none`, `vpm`, `dciem`), or Bühlmann factors it cannot hold.
/// - `average_depth`: metres, where deeper than the maximum.
/// - `entry_altitude`: metres, the altitude of the dive's position.
/// - `tanks`: `[{ gas_number, working_pressure, volume_type }]`, bar and `metric`/`imperial`.
/// - `deco_stop_time`, `setpoint`, `heart_rate`, `bearing`, `remaining_bottom_time`: series on
///   the profile's axis, in seconds, hundredths of a bar, beats a minute, degrees, and the unit
///   the family reports remaining bottom time in.
/// - `ppo2_sensors`: `[{ sensor, times, values }]`, each cell's reading in hundredths of a bar.
/// - `stops`: `[{ time, kind, depth, duration }]`, the safety and deep stops a computer showed,
///   `kind` `safety_stop` or `deep_stop`, centimetres and seconds.
/// - `positions`: `[{ time, latitude, longitude, altitude }]`.
/// - `events`: `[{ time, type, event_time, flags, value }]`, every event as libdivecomputer
///   reported it, `type` its `parser_sample_event_t`.
///
/// Vendor records are not written: their bytes are in the stored original.
enum ComputerDiveDocument {
  static func dive(
    _ dive: ComputerDive, identity: DiveComputerIdentity, uuid: UUID, startedAt: String,
    storedFile: ArchiveJSON
  ) -> ArchiveJSON {
    var out: [String: ArchiveJSON] = [
      "uuid": .string(uuid.uuidString.lowercased()),
      "started_at": .string(startedAt),
    ]
    var extensions: [String: ArchiveJSON] = [:]
    if let time = dive.diveTime, time > 0 { out["submerged_time"] = .integer(time) }
    let maxDepth = dive.maxDepth.flatMap { $0 > 0 ? round($0, 2) : nil }
    if let maxDepth { out["max_depth"] = .number(maxDepth) }
    if let average = dive.averageDepth.flatMap({ $0 > 0 ? round($0, 2) : nil }) {
      if maxDepth.map({ average <= $0 }) ?? true {
        out["avg_depth"] = .number(average)
      } else {
        extensions["average_depth"] = .number(average)
      }
    }
    if let location = dive.location, let position = position(location) {
      out["entry_position"] = position
      if let altitude = location.altitude { extensions["entry_altitude"] = .number(round(altitude, 2)) }
    }
    let (cylinders, mixNumbers) = self.cylinders(dive, extensions: &extensions)
    if !cylinders.isEmpty { out["cylinders"] = .array(cylinders) }
    out["recordings"] = .array([
      recording(
        dive, identity: identity, mixNumbers: mixNumbers, storedFile: storedFile,
        extensions: extensions)
    ])
    return .object(out)
  }

  // MARK: - Cylinders

  private static func cylinders(_ dive: ComputerDive, extensions: inout [String: ArchiveJSON])
    -> ([ArchiveJSON], [Int: Int])
  {
    var cylinders: [ArchiveJSON] = []
    var mixNumbers: [Int: Int] = [:]
    var tanks: [ArchiveJSON] = []
    for (number, tank) in dive.tanks.enumerated() {
      var cylinder: [String: ArchiveJSON] = ["gas_number": .integer(number)]
      var usage = tank.usage
      if let index = tank.gasMix, dive.gasMixes.indices.contains(index) {
        gas(dive.gasMixes[index], into: &cylinder)
        usage = usage ?? dive.gasMixes[index].usage
        if mixNumbers[index] == nil { mixNumbers[index] = number }
      }
      self.usage(usage, into: &cylinder)
      if let volume = tank.volume, volume > 0 { cylinder["volume"] = .number(round(volume, 2)) }
      let start = tank.beginPressure.flatMap { $0 > 0 && $0 <= 350 ? round($0, 2) : nil }
      if let start { cylinder["start_pressure"] = .number(start) }
      if let end = tank.endPressure.flatMap({ $0 > 0 && $0 <= 350 ? round($0, 2) : nil }),
        start.map({ end <= $0 }) ?? true
      {
        cylinder["end_pressure"] = .number(end)
      }
      cylinders.append(.object(cylinder))
      var kept: [String: ArchiveJSON] = [:]
      if let working = tank.workingPressure, working > 0 {
        kept["working_pressure"] = .number(round(working, 2))
      }
      switch tank.volumeType {
      case .metric: kept["volume_type"] = .string("metric")
      case .imperial: kept["volume_type"] = .string("imperial")
      case nil: break
      }
      if !kept.isEmpty {
        kept["gas_number"] = .integer(number)
        tanks.append(.object(kept))
      }
    }
    for (index, mix) in dive.gasMixes.enumerated() where mixNumbers[index] == nil {
      let number = cylinders.count
      mixNumbers[index] = number
      var cylinder: [String: ArchiveJSON] = ["gas_number": .integer(number)]
      gas(mix, into: &cylinder)
      usage(mix.usage, into: &cylinder)
      cylinders.append(.object(cylinder))
    }
    if !tanks.isEmpty { extensions["tanks"] = .array(tanks) }
    return (cylinders, mixNumbers)
  }

  private static func gas(_ mix: ComputerDive.GasMix, into cylinder: inout [String: ArchiveJSON]) {
    let oxygen = round(mix.oxygen * 100, 1)
    guard (0...100).contains(oxygen) else { return }
    cylinder["oxygen"] = .number(oxygen)
    let helium = min(round(mix.helium * 100, 1), round(100 - oxygen, 1))
    if helium >= 0 { cylinder["helium"] = .number(helium) }
  }

  private static func usage(_ usage: ComputerDive.Usage?, into cylinder: inout [String: ArchiveJSON])
  {
    switch usage {
    case .oxygen: cylinder["role"] = .string("oxygen")
    case .diluent: cylinder["role"] = .string("diluent")
    case .sidemount: cylinder["usage"] = .string("parallel")
    case nil: break
    }
  }

  // MARK: - The recording

  private static func recording(
    _ dive: ComputerDive, identity: DiveComputerIdentity, mixNumbers: [Int: Int],
    storedFile: ArchiveJSON, extensions: [String: ArchiveJSON]
  ) -> ArchiveJSON {
    var extensions = extensions
    var out: [String: ArchiveJSON] = ["source_files": .array([storedFile])]
    var device: [String: ArchiveJSON] = [:]
    func put(_ key: String, _ value: String?, limit: Int) {
      guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty
      else { return }
      device[key] = .string(String(value.prefix(limit)))
    }
    put("model", identity.family.deviceModel(vendor: identity.vendor, product: identity.product), limit: 64)
    put("serial", identity.serial, limit: 64)
    put("firmware", identity.firmware, limit: 32)
    if !device.isEmpty { out["device"] = .object(device) }

    switch dive.mode {
    case .freedive: out["mode"] = .string("freedive")
    case .gauge: out["mode"] = .string("gauge")
    case .openCircuit: out["mode"] = .string("open_circuit")
    case .closedCircuit: out["mode"] = .string("closed_circuit")
    case .semiClosed: out["mode"] = .string("semi_closed")
    case nil: break
    }
    decoModel(dive.decoModel, into: &out, extensions: &extensions)
    if let salinity = dive.salinity {
      switch salinity.water {
      case .fresh: out["salinity"] = .string("fresh")
      case .salt:
        // EN 13319's 1020 kg/m³, which the Shearwater parser reports as salt.
        let en13319 = salinity.density.map { abs($0 - 1020) < 0.5 } ?? false
        out["salinity"] = .string(en13319 ? "en13319" : "salt")
      }
      if let density = salinity.density { extensions["salinity_density"] = .number(round(density, 2)) }
    }
    if let pressure = dive.atmosphericPressure.map({ round($0, 4) }) {
      if (0.4...1.2).contains(pressure) {
        out["surface_pressure"] = .number(pressure)
      } else {
        extensions["atmospheric_pressure"] = .number(pressure)
      }
    }
    for (key, value) in [
      ("temperature_surface", dive.surfaceTemperature),
      ("temperature_minimum", dive.minimumTemperature),
      ("temperature_maximum", dive.maximumTemperature),
    ] {
      if let value { extensions[key] = .number(round(value, 2)) }
    }
    if let profile = profile(dive, mixNumbers: mixNumbers, extensions: &extensions) {
      out["profile"] = profile
    }
    if !extensions.isEmpty {
      out["extensions"] = .object([DiveComputerArchive.producerKey: .object(extensions)])
    }
    return .object(out)
  }

  private static func decoModel(
    _ model: ComputerDive.DecoModel?, into out: inout [String: ArchiveJSON],
    extensions: inout [String: ArchiveJSON]
  ) {
    guard let model else { return }
    var spec: [String: ArchiveJSON] = [:]
    var kept: [String: ArchiveJSON] = [:]
    switch model.kind {
    case .buhlmann: spec["algorithm"] = .string("buhlmann")
    case .rgbm: spec["algorithm"] = .string("rgbm")
    case .none: kept["model"] = .string("none")
    case .vpm: kept["model"] = .string("vpm")
    case .dciem: kept["model"] = .string("dciem")
    }
    let target = kept.isEmpty
    if let conservatism = model.conservatism {
      if target { spec["conservatism"] = .integer(conservatism) } else {
        kept["conservatism"] = .integer(conservatism)
      }
    }
    if let factors = model.gradientFactors {
      let fits =
        target && (0...100).contains(factors.low) && (0...100).contains(factors.high)
        && factors.low <= factors.high
      if fits {
        spec["gf_low"] = .integer(factors.low)
        spec["gf_high"] = .integer(factors.high)
      } else {
        kept["gf_low"] = .integer(factors.low)
        kept["gf_high"] = .integer(factors.high)
      }
    }
    if !spec.isEmpty { out["deco_model"] = .object(spec) }
    if !kept.isEmpty { extensions["deco_model"] = .object(kept) }
  }

  // MARK: - The profile

  private struct Series {
    var times: [Int] = []
    var values: [Int] = []

    /// Keeps the first reading at an instant: §6.5's times are strictly increasing.
    mutating func add(_ time: Int, _ value: Int) {
      guard time >= 0, time > (times.last ?? -1) else { return }
      times.append(time)
      values.append(value)
    }

    var json: ArchiveJSON? {
      times.isEmpty ? nil : .object(["times": .array(times.map(ArchiveJSON.integer)), "values": .array(values.map(ArchiveJSON.integer))])
    }
  }

  private static func profile(
    _ dive: ComputerDive, mixNumbers: [Int: Int], extensions: inout [String: ArchiveJSON]
  ) -> ArchiveJSON? {
    guard !dive.samples.isEmpty else { return nil }
    var depth = Series()
    var ceiling = Series()
    var temperature = Series()
    var pressures: [Int: Series] = [:]
    var ndl = Series()
    var tts = Series()
    var ppo2 = Series()
    var cns = Series()
    var events: [ArchiveJSON] = []
    var stopTime = Series()
    var setpoint = Series()
    var heartRate = Series()
    var bearing = Series()
    var remaining = Series()
    var sensors: [Int: Series] = [:]
    var stops: [ArchiveJSON] = []
    var positions: [ArchiveJSON] = []
    var rawEvents: [ArchiveJSON] = []
    var duration = 0

    for sample in dive.samples {
      let t = sample.time
      guard t >= 0 else { continue }
      duration = max(duration, t)
      if let value = sample.depth { depth.add(t, centi(value)) }
      if let value = sample.temperature { temperature.add(t, centi(value)) }
      for pressure in sample.pressures {
        pressures[pressure.tank, default: Series()].add(t, Int((pressure.bar * 10).rounded()))
      }
      if let deco = sample.deco {
        switch deco.kind {
        case .ndl: ndl.add(t, max(0, deco.time))
        case .decoStop:
          ceiling.add(t, centi(deco.depth))
          stopTime.add(t, max(0, deco.time))
        case .safetyStop, .deepStop:
          stops.append(
            .object([
              "time": .integer(t),
              "kind": .string(deco.kind == .safetyStop ? "safety_stop" : "deep_stop"),
              "depth": .integer(centi(deco.depth)), "duration": .integer(deco.time),
            ]))
        }
        if deco.timeToSurface > 0 { tts.add(t, deco.timeToSurface) }
      }
      for reading in sample.ppo2 where reading.bar >= 0 {
        let value = centi(reading.bar)
        if let sensor = reading.sensor {
          sensors[sensor, default: Series()].add(t, value)
        } else {
          ppo2.add(t, value)
        }
      }
      if let value = sample.cns, value >= 0 { cns.add(t, Int((value * 1000).rounded())) }
      if let value = sample.setpoint { setpoint.add(t, centi(value)) }
      if let value = sample.heartRate { heartRate.add(t, value) }
      if let value = sample.bearing { bearing.add(t, value) }
      if let value = sample.remainingBottomTime { remaining.add(t, value) }
      if let location = sample.location, case .object(var fix)? = position(location) {
        fix["time"] = .integer(t)
        if let altitude = location.altitude { fix["altitude"] = .number(round(altitude, 2)) }
        positions.append(.object(fix))
      }
      if let mix = sample.gasMix {
        var event: [String: ArchiveJSON] = ["time": .integer(t), "type": .string("gas_switch")]
        if let number = mixNumbers[mix] { event["gas_number"] = .integer(number) }
        events.append(.object(event))
      }
      for event in sample.events where event.type != 0 {
        events.append(specEvent(event, at: t))
        rawEvents.append(
          .object([
            "time": .integer(t), "type": .integer(event.type), "event_time": .integer(event.time),
            "flags": .integer(event.flags), "value": .integer(event.value),
          ]))
      }
    }

    var out: [String: ArchiveJSON] = ["duration": .integer(duration)]
    for (key, series) in [
      ("depth", depth), ("ceiling", ceiling), ("temperature", temperature), ("ndl", ndl),
      ("tts", tts), ("ppo2", ppo2), ("cns", cns),
    ] {
      if let json = series.json { out[key] = json }
    }
    let pressureSeries: [ArchiveJSON] = pressures.keys.sorted().compactMap { tank in
      guard case .object(var series)? = pressures[tank]?.json else { return nil }
      series["gas_number"] = .integer(tank)
      return .object(series)
    }
    if !pressureSeries.isEmpty { out["pressures"] = .array(pressureSeries) }
    if !events.isEmpty { out["events"] = .array(events) }

    for (key, series) in [
      ("deco_stop_time", stopTime), ("setpoint", setpoint), ("heart_rate", heartRate),
      ("bearing", bearing), ("remaining_bottom_time", remaining),
    ] {
      if let json = series.json { extensions[key] = json }
    }
    let sensorSeries: [ArchiveJSON] = sensors.keys.sorted().compactMap { sensor in
      guard case .object(var series)? = sensors[sensor]?.json else { return nil }
      series["sensor"] = .integer(sensor)
      return .object(series)
    }
    if !sensorSeries.isEmpty { extensions["ppo2_sensors"] = .array(sensorSeries) }
    if !stops.isEmpty { extensions["stops"] = .array(stops) }
    if !positions.isEmpty { extensions["positions"] = .array(positions) }
    if !rawEvents.isEmpty { extensions["events"] = .array(rawEvents) }
    return .object(out)
  }

  /// A libdivecomputer event as the spec's: typed where the vocabulary has its meaning,
  /// labelled with libdivecomputer's name for it otherwise.
  private static func specEvent(_ event: ComputerDive.Sample.Event, at time: Int) -> ArchiveJSON {
    let types = [
      3: "ascent_rate", 4: "ceiling_violation", 8: "bookmark", 10: "safety_stop",
      12: "safety_stop", 13: "safety_stop_mandatory", 14: "deep_stop", 20: "ppo2_high",
    ]
    if let type = types[event.type] {
      return .object(["time": .integer(time), "type": .string(type)])
    }
    let labels = [
      1: "deco stop", 2: "remaining bottom time", 5: "workload", 6: "transmitter",
      7: "violation", 9: "surface", 11: "gas change", 15: "ceiling (safety stop)", 16: "floor",
      17: "dive time", 18: "maximum depth", 19: "OLF", 21: "air time", 22: "RGBM",
      23: "heading", 24: "tissue level", 25: "gas change",
    ]
    return .object([
      "time": .integer(time), "label": .string(labels[event.type] ?? "event \(event.type)"),
    ])
  }

  // MARK: - Values

  private static func position(_ location: ComputerDive.Location) -> ArchiveJSON? {
    guard (-90...90).contains(location.latitude), (-180...180).contains(location.longitude)
    else { return nil }
    return .object([
      "latitude": .number(round(location.latitude, 7)),
      "longitude": .number(round(location.longitude, 7)),
    ])
  }

  /// Hundredths, the spec's scale for depth in centimetres, temperature and ppO₂.
  private static func centi(_ value: Double) -> Int { Int((value * 100).rounded()) }

  static func round(_ value: Double, _ places: Int) -> Double {
    let scale = pow(10, Double(places))
    return (value * scale).rounded() / scale
  }
}
