import Foundation

extension CheckinSheetStore {
  /// Puts `details` into the kept sheet in place of the ones it holds, so a save on the phone
  /// shows on the sheet before its next refresh, with no signal too. Without a kept sheet there
  /// is nothing to change: the next refresh builds one.
  public func replaceDetails(with details: CheckinDetailsRead) throws {
    guard let sheet = load(), sheet.details != details else { return }
    let staging = try beginStaging()
    do {
      for name in sheet.fileNames where hasFile(name) { try staging.carry(name: name) }
      try commit(
        CheckinSheet(
          name: sheet.name, units: sheet.units, details: details, totalDives: sheet.totalDives,
          maxDepth: sheet.maxDepth, lastDiveStart: sheet.lastDiveStart, portrait: sheet.portrait,
          cards: sheet.cards, updatedAt: sheet.updatedAt))
    } catch {
      discardStaging()
      throw error
    }
  }
}

extension CheckinSheet {
  /// Every picture file the sheet names.
  fileprivate var fileNames: Set<String> {
    Set(([portrait] + cards.flatMap { [$0.front, $0.back] }).compactMap { $0?.name })
  }
}
