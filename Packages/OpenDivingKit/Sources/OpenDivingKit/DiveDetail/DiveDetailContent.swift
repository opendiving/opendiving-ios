import Foundation

/// Everything a dive's page draws, as plain values, section by section in the web's
/// order. A section with nothing to show is nil or empty, and is not drawn.
public struct DiveDetailContent: Hashable, Sendable {
  /// `#212`.
  public var navigationTitle: String
  public var hero: HeroContent
  public var profile: Profile?
  public var tanks: Tanks?
  public var gasConsumption: GasConsumption?
  public var exposure: Exposure?
  public var gear: Gear?
  public var sightings: [Sighting]
  public var notes: String?
  /// The training course's name.
  public var course: String?
  public var location: Location?
  public var people: [PersonRowContent]
  /// Air temperature, water type, altitude, current, waves and weather, where recorded.
  public var environment: [Figure]
  public var recordings: [Recording]

  /// The profile card: one chart, and a switcher across the recordings that carry a
  /// profile when there is more than one.
  public struct Profile: Hashable, Sendable {
    /// Each mixture's `gas_number`, in the Tanks card's order, for the chart's legend.
    public var cylinderLabels: [Int?]
    /// The primary first, wherever it has a profile.
    public var recordings: [ChartedRecording]

    public struct ChartedRecording: Hashable, Sendable, Identifiable {
      public var id: UUID
      /// What the switcher calls it: the device, or `Dive computer · Recording 2`.
      public var label: String
      /// `3,600 depth samples recorded by the dive computer, 2 markers, a deco ceiling to
      /// 3.2 m.`, from the summary the dive already carries.
      public var description: String
    }
  }

  /// One card per cylinder, then the dive-wide MOD warning.
  public struct Tanks: Hashable, Sendable {
    public var tanks: [Tank]
    public var warning: String?

    public struct Tank: Hashable, Sendable {
      /// `#1`.
      public var number: String
      /// `EAN32`; nil reads *Gas not recorded*.
      public var gas: String?
      /// The role's label, as a badge.
      public var role: String?
      /// The linked cylinder, the volume, O₂, He and the usage, as recorded.
      public var facts: [String]
      public var start: String?
      public var end: String?
      /// `@ 1.4` beside the MOD's label, the ppO₂ the MOD is worked out at.
      public var modCondition: String?
      public var mod: String?
      /// The dive's warning is about this cylinder's gas.
      public var warned: Bool
    }
  }

  /// The API's gas-consumption figures, as they arrive.
  public enum GasConsumption: Hashable, Sendable {
    /// The dive has a cylinder and no figures.
    case unavailable(String)
    /// One whole-dive figure: RMV, SAC and gas used, with the sentence naming the average
    /// depth they are normalised against.
    case figures([Figure], note: String?)
    /// A row per cylinder, a total where more than one was attributed, and the notes.
    case table(rows: [GasRow], total: GasRow?, note: String, coverage: String?)
  }

  /// One row of the per-tank table.
  public struct GasRow: Hashable, Sendable {
    /// `1`, `Gas 3` or `Total`.
    public var label: String
    public var gas: String?
    public var role: String?
    /// Time, avg depth, used, RMV and SAC, `-` where there is none; nil for a cylinder
    /// with no figures, which says why in ``emptyText``.
    public var cells: [String]?
    public var emptyText: String?
  }

  public struct Exposure: Hashable, Sendable {
    public var readings: [Reading]
    /// `1.013 bar`.
    public var surfacePressure: String?

    /// A start → end pair, a missing half an em dash.
    public struct Reading: Hashable, Sendable {
      public var label: String
      public var start: String
      public var end: String
      /// Why the end value is emphasised; nil when it is not.
      public var alert: String?
    }
  }

  public struct Gear: Hashable, Sendable {
    public var items: [Item]
    public var weight: String?

    public struct Item: Hashable, Sendable {
      public var type: String
      public var brand: String
      public var name: String
      public var rented: Bool
      public var archived: Bool
    }
  }

  /// One species seen. The card's photo is fetched by the view, from ``photoVersion``.
  public struct Sighting: Hashable, Sendable, Identifiable {
    public var id: UUID
    /// The `?v=` of the species' photo; nil means no photo and no request.
    public var photoVersion: String?
    public var card: SpeciesCardContent
  }

  public struct Location: Hashable, Sendable {
    public var trip: Trip?
    public var diveCenter: DiveCenter?
    /// `Dive site` or `Dive sites`.
    public var sitesLabel: String
    public var sites: [Site]
    public var entry: String?
    public var exit: String?
    /// The straight line between the two fixes.
    public var drift: String?
    public var entryType: String?
    public var boatName: String?

    public struct Trip: Hashable, Sendable {
      public var uuid: UUID
      public var name: String
      public var locations: String?
    }

    public struct DiveCenter: Hashable, Sendable {
      public var name: String
      /// City, region and country.
      public var place: String?
      public var phone: String?
      /// The `tel:` link.
      public var phoneURL: URL?
      /// As a link reads it, `example.com/dahab`.
      public var website: String?
      public var websiteURL: URL?
    }

    public struct Site: Hashable, Sendable, Identifiable {
      public var id: UUID
      public var name: String
      public var location: String?
    }
  }

  /// One computer's record of the dive.
  public struct Recording: Hashable, Sendable, Identifiable {
    public var id: UUID
    public var device: String
    /// `Recording 1 · shown by default`, only when the dive has more than one.
    public var name: String?
    public var settings: String?
    public var readouts: String?
    /// `Started 10:05`, only where it differs from the dive's own start.
    public var started: String?
    public var firmware: String?
    public var noFileKept: String?
    public var files: [File]

    public struct File: Hashable, Sendable, Identifiable {
      public var id: UUID
      public var name: String
      /// `Suunto app JSON · 1.2 MB`.
      public var detail: String
    }
  }
}
