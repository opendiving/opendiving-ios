import Foundation

/// A species photo's credit line — *Photo by Raimond Spekking · CC BY-SA 4.0 · Wikimedia
/// Commons* — as runs of text, the licence and the source each a link where it has one.
public struct PhotoCreditContent: Hashable, Sendable {
  public struct Run: Hashable, Sendable {
    public var text: String
    public var url: URL?

    public init(_ text: String, url: URL? = nil) {
      self.text = text
      self.url = url
    }
  }

  public var runs: [Run]

  public init(runs: [Run]) {
    self.runs = runs
  }

  /// The line without its links.
  public var text: String { runs.map(\.text).joined() }
}
