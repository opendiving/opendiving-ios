/// The head of a gear item's page (`GearItemHero`): its name, the type, brand, Rented and
/// Archived under it, and its figures — the vessel's facts where it records any, what it has
/// been dived, and when its next service falls.
public enum GearItemPageContent {
  public static func hero(_ item: GearItemRead, units: UnitSystem, today: CalendarDate)
    -> HeroContent
  {
    let subtitle = [
      VocabularyLabels.gearType(item.type), item.brand, item.rented ? "Rented" : nil,
      item.isArchived ? "Archived" : nil,
    ].compactMap { $0 }.filter { !$0.isEmpty }
    var figures: [Figure] = []
    let vessel = VesselFacts.parts(item, units: units)
    if !vessel.isEmpty {
      figures.append(Figure(label: "Cylinder", value: vessel.joined(separator: " · ")))
    }
    figures.append(Figure(label: "Dives", value: String(item.diveCount)))
    figures.append(
      Figure(label: "Dive time", value: DateText.hoursMinutes(seconds: item.diveTime)))
    if let next = GearServiceText.nextService(
      item.service, diveCount: item.diveCount, diveTime: item.diveTime, today: today)
    {
      figures.append(Figure(label: "Next service", value: nextService(next)))
    }
    return HeroContent(
      title: item.name, facts: subtitle.map { Fact(text: $0) }, figures: figures)
  }

  /// *Next service*'s figure: *Overdue*, the date, or *In 3 dives*, *In 12 hours of diving*.
  static func nextService(_ next: GearServiceText.NextService) -> String {
    switch next {
    case .overdue: "Overdue"
    case .date(let on): DateText.date(on)
    case .dives(let remaining): "In " + GearServiceText.countOf(remaining, .dive)
    case .hours(let remaining): "In " + GearServiceText.countOf(remaining, .hour)
    }
  }

  /// The page's *Notes*, where it has any.
  public static func notes(_ item: GearItemRead) -> String? {
    item.notes.isEmpty ? nil : item.notes
  }
}
