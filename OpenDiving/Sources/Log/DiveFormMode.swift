import Foundation
import OpenDivingKit

/// What the dive form opens on.
enum DiveFormMode: Hashable {
  /// A new dive.
  case create
  /// A dive draft, by the server's uuid or the phone's own.
  case draft(RecordRef)
  /// A dive the account has, by its uuid.
  case edit(UUID)
  /// A queued dive the server refused, by its outbox item's id.
  case failed(UUID)
}
