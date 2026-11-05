/// `PATCH /trip/{uuid}`'s body, `TripUpdateRequest`: only what is set is sent. The name and the
/// notes cannot be cleared; the parts and the people replace the trip's whole lists when sent.
public struct TripUpdate: Codable, Hashable, Sendable {
  public var name: String?
  public var notes: String?
  public var parts: [TripPartWrite]?
  public var people: [PersonReference]?

  public init(
    name: String? = nil, notes: String? = nil, parts: [TripPartWrite]? = nil,
    people: [PersonReference]? = nil
  ) {
    self.name = name
    self.notes = notes
    self.parts = parts
    self.people = people
  }

  /// Whether sending it would change nothing.
  public var isEmpty: Bool { self == TripUpdate() }
}

extension TripUpdate: RewritesLocalRefs {
  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {
    if var list = parts {
      for index in list.indices { list[index].accommodation.rewrite(rewrite) }
      parts = list
    }
    if var list = people {
      list.rewritePeople(rewrite)
      people = list
    }
  }
}
