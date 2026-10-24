/// `GET /dives/recent-volumes`: the cylinder volumes the diver's dives used, in litres, the
/// most recently used first, at most ten.
public struct RecentVolumes: Codable, Hashable, Sendable {
  public let volumes: [Double]
}
