/// The answer to a request sent with `If-None-Match`: the stored copy still holds, or here is
/// a new one with the `ETag` to send next time.
public enum ConditionalFetch<Value: Sendable>: Sendable {
  case notModified
  case fetched(Value, etag: String?)
}

extension ConditionalFetch: Equatable where Value: Equatable {}
