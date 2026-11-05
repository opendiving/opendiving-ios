import Foundation

/// What a trip's or a dive site's form opens on.
enum RecordFormMode<Read: Hashable>: Hashable {
  /// A new record.
  case create
  /// A record the account has, as its page read it.
  case edit(Read)
  /// A queued edit the server refused, by its outbox item's id and the record's uuid.
  case failed(item: UUID, record: UUID)
}
