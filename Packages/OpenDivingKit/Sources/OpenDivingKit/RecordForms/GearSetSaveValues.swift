/// *Save as Set*: the set's values and where they go — a new set, or an existing one they
/// replace whole.
public struct GearSetSaveValues: RecordSheetValues {
  public var form: GearSetFormValues
  /// The set replaced; nil creates one.
  public var target: RecordRef?

  public init(form: GearSetFormValues, target: RecordRef? = nil) {
    self.form = form
    self.target = target
  }

  public var issues: [FormIssue] { form.issues }

  public func operation() throws(FormInvalid) -> OutboxOperation {
    if let target { return .updateGearSet(target, try form.toUpdate()) }
    return .createGearSet(try form.toCreate())
  }

  public init?(reopening operation: OutboxOperation) {
    switch operation {
    case .createGearSet(let body):
      self.init(
        form: GearSetFormValues(name: body.name, weight: body.weight, items: body.gearItems))
    case .updateGearSet(let target, let body):
      self.init(
        form: GearSetFormValues(
          name: body.name ?? "", weight: body.weight.applied(to: nil),
          items: body.gearItems ?? []),
        target: target)
    default:
      return nil
    }
  }
}
