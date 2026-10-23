/// `GET /dive/{uuid}/neighbors`. `next` is later in time.
public struct DiveNeighbors: Codable, Hashable, Sendable {
  public let previous: DiveNeighbor?
  public let next: DiveNeighbor?
}
