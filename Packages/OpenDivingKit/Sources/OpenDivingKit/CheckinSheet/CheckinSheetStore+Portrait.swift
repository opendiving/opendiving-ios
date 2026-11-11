import Foundation

extension CheckinSheetStore {
  /// Puts the portrait `version` names into the kept sheet in place of the one it holds — none
  /// for nil — so a portrait saved on the phone shows on the sheet before its next refresh, with
  /// no signal too. Without a kept sheet, or with that version kept already, nothing changes.
  @MainActor
  public func replacePortrait(version: String?, using client: APIClient) async throws {
    guard let sheet = load(), sheet.portrait?.version != version else { return }
    var fetched: (bytes: FetchedBytes, etag: String?)?
    if let version {
      guard
        case .fetched(let bytes, let etag) = try await client.portrait(version: version, etag: nil)
      else { throw APIError.unreadableResponse("304 for portrait with no ETag sent") }
      fetched = (bytes, etag)
    }
    let staging = try beginStaging()
    do {
      var portrait: CheckinSheetFile?
      if let version, let fetched {
        try staging.write(fetched.bytes.data, name: "portrait")
        portrait = CheckinSheetFile(
          name: "portrait", version: version, etag: fetched.etag,
          contentType: fetched.bytes.contentType)
      }
      let kept = sheet.fileNames.subtracting(sheet.portrait.map { [$0.name] } ?? [])
      for name in kept where hasFile(name) { try staging.carry(name: name) }
      try commit(
        CheckinSheet(
          name: sheet.name, units: sheet.units, details: sheet.details,
          totalDives: sheet.totalDives, maxDepth: sheet.maxDepth,
          lastDiveStart: sheet.lastDiveStart, portrait: portrait, cards: sheet.cards,
          updatedAt: sheet.updatedAt))
    } catch {
      discardStaging()
      throw error
    }
  }
}
