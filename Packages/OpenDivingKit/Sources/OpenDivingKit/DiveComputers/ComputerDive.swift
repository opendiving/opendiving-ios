import Foundation

/// One dive as libdivecomputer's parser reported it, in Swift terms and nothing else's. Every
/// member but the start is optional, and present only where the parser reported the field: the
/// conformance reads `DC_STATUS_UNSUPPORTED` as absent, never as a default, and reads the
/// absences libdivecomputer reports inside a successful field the same way — Bühlmann gradient
/// factors of 0/0, a `DC_TANKVOLUME_NONE` tank's zero volume and working pressure, a zero
/// working pressure, a gas index of `DC_GASMIX_UNKNOWN`, a `DC_SENSOR_NONE` sensor. Each sample
/// value sits on the sample it was reported in; nothing is carried forward.
///
/// Units are libdivecomputer's: metres, °C, bar, litres, seconds, gas fractions from 0 to 1,
/// CNS as a fraction, and milliseconds on the sample axis.
public struct ComputerDive: Hashable, Sendable {
  /// When the dive started, as the parser reported it.
  public enum Start: Hashable, Sendable {
    /// The computer's wall clock, with its offset from UTC in seconds where the parser
    /// reported a zone. The Shearwater family logs a wall clock with no zone.
    case wallClock(LocalDateTime, utcOffsetSeconds: Int?)
    /// An instant with no local clock: the Suunto Nautic family's, which the writer resolves
    /// in a zone the watch or the diver supplies.
    case instant(Date)
  }

  public enum Mode: Hashable, Sendable {
    case freedive, gauge, openCircuit, closedCircuit, semiClosed
  }

  public enum Usage: Hashable, Sendable {
    case oxygen, diluent, sidemount
  }

  public struct GasMix: Hashable, Sendable {
    public var oxygen: Double
    public var helium: Double
    public var usage: Usage?

    public init(oxygen: Double, helium: Double, usage: Usage? = nil) {
      self.oxygen = oxygen
      self.helium = helium
      self.usage = usage
    }
  }

  public struct Tank: Hashable, Sendable {
    public enum VolumeType: Hashable, Sendable {
      /// Water capacity, as metric cylinders are named.
      case metric
      /// Air capacity at working pressure, which libdivecomputer has converted to water
      /// capacity in ``volume``.
      case imperial
    }

    /// The index into ``ComputerDive/gasMixes`` of the gas it held.
    public var gasMix: Int?
    public var volumeType: VolumeType?
    public var volume: Double?
    public var workingPressure: Double?
    public var beginPressure: Double?
    public var endPressure: Double?
    public var usage: Usage?

    public init(
      gasMix: Int? = nil, volumeType: VolumeType? = nil, volume: Double? = nil,
      workingPressure: Double? = nil, beginPressure: Double? = nil, endPressure: Double? = nil,
      usage: Usage? = nil
    ) {
      self.gasMix = gasMix
      self.volumeType = volumeType
      self.volume = volume
      self.workingPressure = workingPressure
      self.beginPressure = beginPressure
      self.endPressure = endPressure
      self.usage = usage
    }
  }

  public struct DecoModel: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
      case none, buhlmann, vpm, rgbm, dciem
    }

    /// Bühlmann gradient factors, in whole percent.
    public struct GradientFactors: Hashable, Sendable {
      public var low: Int
      public var high: Int

      public init(low: Int, high: Int) {
        self.low = low
        self.high = high
      }
    }

    public var kind: Kind
    public var conservatism: Int?
    public var gradientFactors: GradientFactors?

    public init(kind: Kind, conservatism: Int? = nil, gradientFactors: GradientFactors? = nil) {
      self.kind = kind
      self.conservatism = conservatism
      self.gradientFactors = gradientFactors
    }
  }

  public struct Salinity: Hashable, Sendable {
    public enum Water: Hashable, Sendable {
      case fresh, salt
    }

    public var water: Water
    /// kg/m³, where reported.
    public var density: Double?

    public init(water: Water, density: Double? = nil) {
      self.water = water
      self.density = density
    }
  }

  public struct Location: Hashable, Sendable {
    public var latitude: Double
    public var longitude: Double
    public var altitude: Double?

    public init(latitude: Double, longitude: Double, altitude: Double? = nil) {
      self.latitude = latitude
      self.longitude = longitude
      self.altitude = altitude
    }
  }

  public struct Sample: Hashable, Sendable {
    public struct Pressure: Hashable, Sendable {
      /// The index into ``ComputerDive/tanks``.
      public var tank: Int
      public var bar: Double

      public init(tank: Int, bar: Double) {
        self.tank = tank
        self.bar = bar
      }
    }

    public struct Event: Hashable, Sendable {
      /// libdivecomputer's `parser_sample_event_t`.
      public var type: Int
      public var time: Int
      public var flags: Int
      public var value: Int

      public init(type: Int, time: Int = 0, flags: Int = 0, value: Int = 0) {
        self.type = type
        self.time = time
        self.flags = flags
        self.value = value
      }
    }

    public struct PPO2: Hashable, Sendable {
      /// The sensor's index; nil for the value the computer calculated (`DC_SENSOR_NONE`).
      public var sensor: Int?
      public var bar: Double

      public init(sensor: Int?, bar: Double) {
        self.sensor = sensor
        self.bar = bar
      }
    }

    public struct Deco: Hashable, Sendable {
      public enum Kind: Hashable, Sendable {
        case ndl, safetyStop, decoStop, deepStop
      }

      public var kind: Kind
      /// Seconds: the no-decompression time for ``Kind/ndl``, the stop's time otherwise.
      public var time: Int
      /// Metres: the stop's depth.
      public var depth: Double
      /// Seconds to the surface; libdivecomputer reports zero where the computer gave none.
      public var timeToSurface: Int

      public init(kind: Kind, time: Int, depth: Double, timeToSurface: Int = 0) {
        self.kind = kind
        self.time = time
        self.depth = depth
        self.timeToSurface = timeToSurface
      }
    }

    public struct Vendor: Hashable, Sendable {
      public var type: Int
      public var bytes: Data

      public init(type: Int, bytes: Data) {
        self.type = type
        self.bytes = bytes
      }
    }

    /// Milliseconds from the dive's start.
    public var time: Int
    public var depth: Double?
    public var temperature: Double?
    public var pressures: [Pressure] = []
    public var events: [Event] = []
    /// Remaining bottom time, in the unit the family reports it in.
    public var remainingBottomTime: Int?
    public var heartRate: Int?
    /// Degrees.
    public var bearing: Int?
    public var setpoint: Double?
    public var ppo2: [PPO2] = []
    public var cns: Double?
    public var deco: Deco?
    /// The gas switched to, as an index into ``ComputerDive/gasMixes``.
    public var gasMix: Int?
    public var location: Location?
    public var vendor: [Vendor] = []

    public init(time: Int, depth: Double? = nil, temperature: Double? = nil) {
      self.time = time
      self.depth = depth
      self.temperature = temperature
    }
  }

  public var start: Start
  /// Seconds.
  public var diveTime: Int?
  public var maxDepth: Double?
  public var averageDepth: Double?
  public var surfaceTemperature: Double?
  public var minimumTemperature: Double?
  public var maximumTemperature: Double?
  public var gasMixes: [GasMix] = []
  public var tanks: [Tank] = []
  public var mode: Mode?
  public var decoModel: DecoModel?
  public var salinity: Salinity?
  /// Bar.
  public var atmosphericPressure: Double?
  public var location: Location?
  public var samples: [Sample] = []

  public init(start: Start) {
    self.start = start
  }
}
