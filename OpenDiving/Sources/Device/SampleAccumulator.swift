@preconcurrency import Clibdivecomputer
import Foundation
import OpenDivingKit

/// Collects the parser's sample callbacks into samples: a `DC_SAMPLE_TIME` opens the next one,
/// and each value lands on the sample open when it was reported.
nonisolated struct SampleAccumulator {
  private var samples: [ComputerDive.Sample] = []
  private var current: ComputerDive.Sample?

  mutating func add(_ type: dc_sample_type_t, _ value: dc_sample_value_t) {
    if type == DC_SAMPLE_TIME {
      if let current { samples.append(current) }
      current = ComputerDive.Sample(time: Int(value.time))
      return
    }
    // A value before the first time belongs to the dive's first moment.
    var sample = current ?? ComputerDive.Sample(time: 0)
    switch type {
    case DC_SAMPLE_DEPTH:
      sample.depth = value.depth
    case DC_SAMPLE_PRESSURE:
      sample.pressures.append(.init(tank: Int(value.pressure.tank), bar: value.pressure.value))
    case DC_SAMPLE_TEMPERATURE:
      sample.temperature = value.temperature
    case DC_SAMPLE_EVENT:
      sample.events.append(
        .init(
          type: Int(value.event.type), time: Int(value.event.time),
          flags: Int(value.event.flags), value: Int(value.event.value)))
    case DC_SAMPLE_RBT:
      sample.remainingBottomTime = Int(value.rbt)
    case DC_SAMPLE_HEARTBEAT:
      sample.heartRate = Int(value.heartbeat)
    case DC_SAMPLE_BEARING:
      sample.bearing = Int(value.bearing)
    case DC_SAMPLE_VENDOR:
      let bytes =
        value.vendor.data.map { Data(bytes: $0, count: Int(value.vendor.size)) } ?? Data()
      sample.vendor.append(.init(type: Int(value.vendor.type), bytes: bytes))
    case DC_SAMPLE_SETPOINT:
      sample.setpoint = value.setpoint
    case DC_SAMPLE_PPO2:
      let sensor = value.ppo2.sensor
      sample.ppo2.append(
        .init(sensor: sensor == DC_SENSOR_NONE ? nil : Int(sensor), bar: value.ppo2.value))
    case DC_SAMPLE_CNS:
      sample.cns = value.cns
    case DC_SAMPLE_DECO:
      if let kind = Self.decoKind(value.deco.type) {
        sample.deco = .init(
          kind: kind, time: Int(value.deco.time), depth: value.deco.depth,
          timeToSurface: Int(value.deco.tts))
      }
    case DC_SAMPLE_GASMIX:
      if value.gasmix != DC_GASMIX_UNKNOWN { sample.gasMix = Int(value.gasmix) }
    case DC_SAMPLE_LOCATION:
      sample.location = LibDCDiveParser.location(value.location)
    default:
      break
    }
    current = sample
  }

  /// The samples, the last one closed.
  mutating func finish() -> [ComputerDive.Sample] {
    if let current { samples.append(current) }
    current = nil
    return samples
  }

  private static func decoKind(_ type: UInt32) -> ComputerDive.Sample.Deco.Kind? {
    switch dc_deco_type_t(type) {
    case DC_DECO_NDL: .ndl
    case DC_DECO_SAFETYSTOP: .safetyStop
    case DC_DECO_DECOSTOP: .decoStop
    case DC_DECO_DEEPSTOP: .deepStop
    default: nil
    }
  }
}
