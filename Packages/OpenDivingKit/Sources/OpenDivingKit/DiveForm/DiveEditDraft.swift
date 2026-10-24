import Foundation

/// An edit of a dive the server holds, kept on the phone until it is saved: the dive as it was
/// loaded, which is what the edit's diff compares against, and the values the diver has made of
/// it. An edit is never a server draft — a draft is a dive not yet logged.
public struct DiveEditDraft: Codable, Hashable, Sendable {
  /// The dive as the form opened on it.
  public let baseline: DiveReadWithMixtures
  public var values: DiveFormValues

  /// An edit just begun: the values are the dive's own.
  public init(editing dive: DiveReadWithMixtures) {
    baseline = dive
    values = DiveFormValues(editing: dive)
  }

  public init(baseline: DiveReadWithMixtures, values: DiveFormValues) {
    self.baseline = baseline
    self.values = values
  }

  /// The dive being edited.
  public var dive: UUID { baseline.uuid }

  /// The `PATCH` this edit makes: what the diver changed since the dive was loaded.
  public func update() throws(FormInvalid) -> DiveUpdate {
    try values.diff(from: baseline)
  }
}

extension DiveEditDraft: RewritesLocalRefs {
  /// Rewrites what the diver picked; the baseline is the server's read and names only what the
  /// server holds.
  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {
    values.rewriteRefs(rewrite)
  }
}
