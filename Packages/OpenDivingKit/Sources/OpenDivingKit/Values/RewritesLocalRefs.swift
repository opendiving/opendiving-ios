/// A value that names records and can have every one of those names rewritten: a local ref
/// replaced by the server's uuid when its create lands, and a ref — local or server — dropped
/// when a discard releases it or a move between accounts strands it. The queue and the draft
/// stores rewrite what they hold through this without knowing its shape.
public protocol RewritesLocalRefs {
  /// Calls `rewrite` on every ``RecordRef`` the value holds and keeps what it answers: the
  /// same ref, another one, or nil to drop it. A dropped reference is no longer sent — a
  /// scalar one becomes absent, an entry of a list leaves the list — and the rest of the
  /// value goes on without it.
  mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?)
}

extension Optional where Wrapped == RecordRef {
  mutating func rewrite(_ rewrite: (RecordRef) -> RecordRef?) {
    self = flatMap(rewrite)
  }
}

extension Array where Element == RecordRef {
  mutating func rewrite(_ rewrite: (RecordRef) -> RecordRef?) {
    self = compactMap(rewrite)
  }
}

extension Array where Element: RewritesLocalRefs {
  mutating func rewriteEach(_ rewrite: (RecordRef) -> RecordRef?) {
    for index in indices {
      self[index].rewriteRefs(rewrite)
    }
  }
}

extension Optional where Wrapped: RewritesLocalRefs {
  mutating func rewriteWrapped(_ rewrite: (RecordRef) -> RecordRef?) {
    guard var value = self else { return }
    value.rewriteRefs(rewrite)
    self = value
  }
}
