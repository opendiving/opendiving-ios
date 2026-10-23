/// A dive's depth curve at a list card's resolution: `values[i]` is the deepest reading, in
/// centimetres, in the `i`th of `values.count` equal slices of `span` milliseconds.
public struct DepthOutline: Codable, Hashable, Sendable {
  public let span: Int
  public let values: [Int]
}
