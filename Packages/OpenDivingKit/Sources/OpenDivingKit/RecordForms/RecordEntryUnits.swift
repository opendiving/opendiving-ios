import Foundation
import Observation

/// The units a record sheet's measured boxes take — the account's, or the diver's override on
/// this phone, which the dive form shares — and the toggle beside each.
@MainActor
@Observable
public final class RecordEntryUnits {
  public private(set) var entry: EntryUnits
  public let account: UnitSystem
  @ObservationIgnored private let store: EntryUnitsStore?

  public init(session: Session) {
    account = session.units
    store = AccountStores.current(session).map {
      EntryUnitsStore(store: $0.store, origin: $0.origin, account: $0.account)
    }
    entry = store?.load() ?? EntryUnits()
  }

  public func units(_ measure: Measure) -> UnitSystem {
    entry.units(measure, account: account)
  }

  /// Flips `measure` and keeps the choice; a choice that cannot be written lasts the sheet.
  public func toggle(_ measure: Measure) {
    entry.toggle(measure, account: account)
    try? store?.save(entry)
  }

  /// A stored metric value as the box shows it in `units`: rounded as the web's number input
  /// shows it, empty for none.
  public static func text(_ metric: Double?, _ measure: Measure, _ units: UnitSystem) -> String {
    guard let metric else { return "" }
    return NumberText.plain(NumberText.round(measure.toDisplay(metric, units), decimals: 2))
  }

  /// What a box's text stores: nil for an empty box, the metric value of a number, and a
  /// sentence for text that is not one.
  public static func value(_ text: String, _ measure: Measure, _ units: UnitSystem)
    -> Result<Double?, EntryText>
  {
    guard !text.trimmedOfWhitespace.isEmpty else { return .success(nil) }
    guard let number = DecimalEntry.parse(text) else {
      return .failure(EntryText(message: DecimalEntry.message(text) ?? "Enter a number."))
    }
    return .success(measure.fromDisplay(number, units))
  }
}

/// A box whose text is not a number, and the sentence under it.
public struct EntryText: Error, Hashable, Sendable {
  public let message: String
}
