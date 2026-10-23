/// One run of a trip's dives on its page: a part's, headed by its place and dates, or the
/// dives between parts that no part's dates cover.
public enum TripDiveSection<Item: Sendable>: Sendable {
  /// The part at `index` in the trip's own order, with the dives made on it. Empty for a
  /// part no dive falls in, which is still shown.
  case part(index: Int, items: [Item])
  /// A run of neighbouring dives no part covers.
  case loose([Item])

  /// The trip's parts and dives as a run of sections, newest first as the dives come: a
  /// section for every part, and the dives no part covers between them.
  ///
  /// A dive is the part's whose dates cover `day(dive)` — its wall-clock day, the day the
  /// diver was there — by ``TripText/partForDay(_:day:)``. A part sits where its first
  /// dive falls; one holding none, where its last day falls among the dives; one with no
  /// dates either, just above the part it follows in the diver's order, or below the one
  /// it precedes when it leads.
  ///
  /// `complete: false` is a list with pages still to load. A dated part holding no loaded
  /// dive is then left out unless every day it covers is later than the oldest loaded
  /// dive's: its dives may be on the next page, and a part drawn empty and then filled
  /// says the wrong thing first.
  public static func sections(
    _ items: [Item],
    parts: [(start: CalendarDate?, end: CalendarDate?)],
    complete: Bool = true,
    day: (Item) -> CalendarDate
  ) -> [TripDiveSection<Item>] {
    var partItems = Array(repeating: [Item](), count: parts.count)
    var slots: [Slot] = []
    var placed = Set<Int>()

    for item in items {
      if let index = TripText.partForDay(parts, day: day(item)) {
        partItems[index].append(item)
        if placed.insert(index).inserted { slots.append(.part(index)) }
        continue
      }
      if case .loose(let run) = slots.last {
        slots[slots.count - 1] = .loose(run + [item])
      } else {
        slots.append(.loose([item]))
      }
    }

    // Whether a part holds a dive is only known once every dive is read, so the dated
    // parts are kept by their last day and the empty ones slotted in after.
    let pending = parts.enumerated().compactMap { index, part in
      (part.end ?? part.start).map { (index: index, day: $0) }
    }
    let oldest = items.last.map(day)
    let unsettled: Set<Int> =
      complete
      ? []
      : Set(
        pending.filter { entry in
          guard let start = parts[entry.index].start, let oldest else { return true }
          return start <= oldest
        }.map(\.index))

    // A dive-less dated part goes above the first section wholly older than its last day,
    // splitting a run of loose dives where it falls inside one.
    for entry in pending where !placed.contains(entry.index) && !unsettled.contains(entry.index) {
      var at = slots.count
      search: for position in slots.indices {
        switch slots[position] {
        case .part(let index):
          let newest =
            partItems[index].first.map(day) ?? parts[index].end ?? parts[index].start
          if let newest, newest < entry.day {
            at = position
            break search
          }
        case .loose(let run):
          guard let split = run.firstIndex(where: { day($0) < entry.day }) else { continue }
          if split > 0 {
            slots[position] = .loose(Array(run[..<split]))
            slots.insert(.loose(Array(run[split...])), at: position + 1)
            at = position + 1
          } else {
            at = position
          }
          break search
        }
      }
      slots.insert(.part(entry.index), at: at)
      placed.insert(entry.index)
    }

    // Dateless parts, by their neighbours in the diver's order. Shown newest first, the
    // part a dateless one follows sits below it.
    func position(of index: Int) -> Int? {
      slots.firstIndex {
        if case .part(index) = $0 { true } else { false }
      }
    }
    for index in parts.indices where !placed.contains(index) && !unsettled.contains(index) {
      var at: Int?
      if let before = (0..<index).reversed().first(where: placed.contains) {
        at = position(of: before)
      } else if let after = (index + 1..<parts.count).first(where: placed.contains) {
        at = position(of: after).map { $0 + 1 }
      }
      slots.insert(.part(index), at: at ?? slots.count)
      placed.insert(index)
    }

    return slots.map { slot in
      switch slot {
      case .part(let index): .part(index: index, items: partItems[index])
      case .loose(let run): .loose(run)
      }
    }
  }

  private enum Slot {
    case part(Int)
    case loose([Item])
  }
}

extension TripDiveSection: Equatable where Item: Equatable {}
extension TripDiveSection: Hashable where Item: Hashable {}
