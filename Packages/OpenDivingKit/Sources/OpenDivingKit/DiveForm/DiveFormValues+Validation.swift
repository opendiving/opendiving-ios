/// Which save a dive form's values are checked for: a new dive must state its number, its start
/// with an offset and its time; an edit sends only what it holds, and a start without an offset
/// is the server's to accept or refuse, since the rule turns on the stored dive.
public enum DiveFormPurpose: Sendable, Hashable {
  case create
  case edit
}

/// The bounds behind the dive form's sentences, the API's own.
public enum DiveFormBounds {
  /// The most a Postgres `integer` holds, the ceiling of every count the API bounds by its
  /// column alone.
  public static let integerMax = 2_147_483_647
  /// Bar, for every cylinder pressure: above any real fill, so what it catches is a unit slip.
  public static let maxPressureBar = 350.0
  public static let altitudeRange = -450...6500
  public static let ratingRange = 1...5
  public static let po2LimitRange = 0.4...2.0
  public static let boatNameMax = 255
  /// Counted in characters, as the API counts them.
  public static let tagMax = 64
  public static let notesMax = 100_000
}

extension DiveFormValues {
  /// Every sentence the web's dive schema shows for these values, one per field, for `purpose`
  /// — and the one rule the web leaves to the server, an average depth deeper than the maximum,
  /// which a dive queued offline would otherwise learn about only when it is sent.
  public func issues(for purpose: DiveFormPurpose) -> [FormIssue] {
    var list = FormIssueList()

    if let diveNumber {
      if diveNumber <= 0 {
        list.add("dive_number", "Dive number must be a positive integer")
      } else if diveNumber > DiveFormBounds.integerMax {
        list.add(
          "dive_number",
          "Dive number must be at most \(NumberText.grouped(DiveFormBounds.integerMax))")
      }
    } else if purpose == .create {
      // Zod's own sentence for a number box left empty, which the web's form shows as it is.
      list.add("dive_number", "Invalid input: expected number, received undefined")
    }

    if purpose == .create {
      switch startTime {
      case nil: list.add("start_time", "Start time is required")
      case .instant: break
      case .wallClock, .day:
        list.add(
          "start_time", "Start time must include a UTC offset, e.g. 2021-04-04T10:04:47+02:00")
      }
    }

    if submergedTime.isEmpty {
      list.add("submerged_time", "Dive time is required")
    } else if DiveDuration.seconds(fromForm: submergedTime) == nil {
      list.add("submerged_time", "Dive time must be minutes or MM:SS, e.g. 45 or 67:30")
    }

    if let maxDepth, maxDepth <= 0 { list.add("max_depth", "Max depth must be positive") }
    if let avgDepth, avgDepth <= 0 { list.add("avg_depth", "Average depth must be positive") }
    if let avgDepth, let maxDepth, avgDepth > maxDepth {
      list.add("avg_depth", "Average depth cannot be greater than max depth.")
    }
    if let visibility {
      if visibility <= 0 {
        list.add("visibility", "Visibility must be positive")
      } else if visibility > DiveFormBounds.integerMax {
        list.add("visibility", "That's more than a visibility can hold")
      }
    }
    if let altitude, !DiveFormBounds.altitudeRange.contains(altitude) {
      list.add("altitude", Self.altitudeRangeMessage)
    }
    if let rating, !DiveFormBounds.ratingRange.contains(rating) {
      list.add("rating", "Rating must be between 1 and 5")
    }
    if let weight, weight < 0 { list.add("weight", "Weight must be zero or positive") }
    if boatName.utf16.count > DiveFormBounds.boatNameMax {
      list.add("boat_name", FormText.tooLong("Boat name", DiveFormBounds.boatNameMax))
    }
    if tags.contains(where: { $0.unicodeScalars.count > DiveFormBounds.tagMax }) {
      list.add("tags", "A tag can be at most \(DiveFormBounds.tagMax) characters")
    }
    if notes.utf16.count > DiveFormBounds.notesMax {
      list.add("notes", FormText.tooLong("Notes", DiveFormBounds.notesMax))
    }

    for (index, tank) in tanks.enumerated() {
      Self.check(tank, index, into: &list)
    }
    for (index, sighting) in sightings.enumerated() {
      Self.check(sighting, index, into: &list)
    }
    return list.issues
  }

  /// Throws the form's sentences when there are any.
  public func validate(for purpose: DiveFormPurpose) throws(FormInvalid) {
    let found = issues(for: purpose)
    if !found.isEmpty { throw FormInvalid(issues: found) }
  }

  /// The altitude band in both systems, since form state is metric whichever way the diver
  /// typed: `Altitude must be between -450 and 6500 m (-1,476 and 21,325 ft)`.
  static let altitudeRangeMessage: String = {
    let low = Measure.altitude.displayBound(
      Double(DiveFormBounds.altitudeRange.lowerBound), .imperial, isMinimum: true)
    let high = Measure.altitude.displayBound(
      Double(DiveFormBounds.altitudeRange.upperBound), .imperial, isMinimum: false)
    return "Altitude must be between \(DiveFormBounds.altitudeRange.lowerBound) and "
      + "\(DiveFormBounds.altitudeRange.upperBound) m (\(NumberText.grouped(Int(low))) and "
      + "\(NumberText.grouped(Int(high))) ft)"
  }()

  /// The pressure ceiling in both systems: `must be at most 350 bar (5,076 psi) — check the
  /// units on that reading.`
  static let pressureCeilingClause: String = {
    let psi = Int(NumberText.round(Measure.pressure.toDisplay(DiveFormBounds.maxPressureBar, .imperial)))
    return "must be at most \(NumberText.plain(DiveFormBounds.maxPressureBar)) bar "
      + "(\(NumberText.grouped(psi)) psi) — check the units on that reading."
  }()

  private static func check(_ tank: TankValues, _ index: Int, into list: inout FormIssueList) {
    func add(_ member: String, _ message: String) {
      list.add("mixtures", index: index, member: member, message)
    }
    if let volume = tank.volume, volume <= 0 { add("volume", "Volume must be positive") }
    if let start = tank.startPressure {
      if start <= 0 {
        add(
          "start_pressure",
          "A cylinder can't start a dive empty — enter the fill pressure, or leave this blank if it wasn't recorded."
        )
      } else if start > DiveFormBounds.maxPressureBar {
        add("start_pressure", "Start pressure " + pressureCeilingClause)
      }
    }
    if let end = tank.endPressure {
      if end < 0 {
        add("end_pressure", "End pressure must be zero or positive")
      } else if end > DiveFormBounds.maxPressureBar {
        add("end_pressure", "End pressure " + pressureCeilingClause)
      }
    }
    if let oxygen = tank.oxygen {
      if oxygen < 0 {
        add("oxygen", "Oxygen percentage must be at least 0")
      } else if oxygen > 100 {
        add("oxygen", "Oxygen percentage must be at most 100")
      }
    }
    if let helium = tank.helium {
      if helium < 0 {
        add("helium", "Helium percentage must be at least 0")
      } else if helium > 100 {
        add("helium", "Helium percentage must be at most 100")
      }
    }
    if let po2 = tank.po2Limit {
      if po2 < DiveFormBounds.po2LimitRange.lowerBound {
        add("po2_limit", "ppO₂ limit must be at least 0.4 bar")
      } else if po2 > DiveFormBounds.po2LimitRange.upperBound {
        add("po2_limit", "ppO₂ limit must be at most 2.0 bar")
      }
    }
    // The cross-field rules run beside the per-field ones, as the web's do.
    if let start = tank.startPressure, let end = tank.endPressure, end > start {
      add("end_pressure", "End pressure cannot be greater than start pressure")
    }
    if let oxygen = tank.oxygen, let helium = tank.helium, (0...100).contains(oxygen),
      (0...100).contains(helium), oxygen + helium > 100
    {
      add("helium", "Oxygen and helium together cannot exceed 100%")
    }
  }

  private static func check(_ sighting: SightingWrite, _ index: Int, into list: inout FormIssueList)
  {
    if let count = sighting.count {
      if count < 1 {
        list.add(
          "sightings", index: index, member: "count",
          "A count is at least 1 — leave it blank if you didn't count")
      } else if count > DiveFormBounds.integerMax {
        list.add("sightings", index: index, member: "count", "That's more than a count can hold")
      }
    }
    if sighting.notes.utf16.count > DiveFormBounds.notesMax {
      list.add(
        "sightings", index: index, member: "notes",
        FormText.tooLong("Notes", DiveFormBounds.notesMax))
    }
    if sighting.count != nil && sighting.abundance != nil {
      list.add(
        "sightings", index: index, member: "abundance",
        "A sighting carries a count or a band, not both")
    }
  }
}
