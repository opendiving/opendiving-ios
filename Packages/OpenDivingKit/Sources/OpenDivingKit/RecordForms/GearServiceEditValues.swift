import Foundation

/// A schedule's or a service's form values, which edit a record whose writes also name the gear
/// item it belongs to — the one thing ``RecordEditValues``'s static delete cannot know.
public protocol GearServiceEditValues: RecordSheetValues {
  /// The gear item the record belongs to.
  var gearItem: RecordRef { get }
  /// The write taking `ref` from `baseline` to these values; nil when they agree.
  func update(of ref: RecordRef, from baseline: Self) throws(FormInvalid) -> OutboxOperation?
  /// These values with `operation` laid over, where it is a queued update of this kind.
  func applying(_ operation: OutboxOperation) -> Self
  /// The write that deletes `ref`, a record of `gearItem`.
  static func delete(_ ref: RecordRef, gearItem: RecordRef) -> OutboxOperation
}

extension RecordSheetModel where Values: GearServiceEditValues {
  /// Edits `ref`, read as `read`, as ``RecordSheetModel/init(outbox:editing:read:failedItem:)``
  /// edits any other record: its queued updates laid over, and `failedItem` a refused one.
  public convenience init(
    outbox: OutboxModel, editing ref: RecordRef, read: Values, failedItem: UUID? = nil
  ) {
    func laidOver(_ writes: [OutboxItem]) -> Values {
      writes.reduce(read) { $0.applying($1.operation) }
    }
    let writes = outbox.items.filter { $0.operation.target == ref }
    let baseline = laidOver(writes.filter { !$0.isFailed && $0.id != failedItem })
    self.init(
      outbox: outbox, values: laidOver(writes.filter { !$0.isFailed || $0.id == failedItem }),
      failed: writes.first { $0.id == failedItem },
      editing: Editing(
        ref: ref, write: { try $0.update(of: ref, from: baseline) },
        delete: Values.delete(ref, gearItem: read.gearItem)))
  }
}
