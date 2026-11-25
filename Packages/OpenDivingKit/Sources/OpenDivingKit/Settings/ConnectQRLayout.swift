import Foundation

/// What the connect link's QR code draws, in modules with (0, 0) at the symbol's top-left corner,
/// quiet zone not counted: the finders and alignment patterns as whole shapes, the data modules
/// around them, and the brand mark at the centre with the modules near its bubbles left out.
/// The web draws the same symbol from the same numbers.
public struct ConnectQRLayout: Sendable {
  /// A module's corners, for a module drawn rounded where nothing drawn meets it.
  public struct Corners: OptionSet, Sendable, Hashable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    public static let topLeft = Corners(rawValue: 1)
    public static let topRight = Corners(rawValue: 2)
    public static let bottomRight = Corners(rawValue: 4)
    public static let bottomLeft = Corners(rawValue: 8)
  }

  /// A position in the symbol.
  public struct Module: Sendable, Hashable {
    public let row: Int
    public let column: Int

    public init(row: Int, column: Int) {
      self.row = row
      self.column = column
    }
  }

  /// Where the mark's 24-unit box lands: its top-left corner, `offset` modules in on each axis,
  /// and the modules a unit is.
  public struct Mark: Sendable, Equatable {
    public let offset: Double
    public let scale: Double
  }

  /// The logo's three bubbles in its 24-unit box, as `BrandMark` draws them: x, y and radius,
  /// the first filled.
  public static let markBubbles: [(x: Double, y: Double, radius: Double)] = [
    (5.17, 20.22, 1.78), (10.72, 13.56, 2.89), (16.83, 5.78, 3.78),
  ]
  /// The bubbles' stroke, in the box's units.
  public static let markStroke = 2.6

  /// The modules a side, 4 × version + 17.
  public let size: Int
  public let version: Int
  /// The top-left module of each 7 × 7 finder.
  public let finders: [Module]
  /// The centre module of each 5 × 5 alignment pattern.
  public let alignments: [Module]
  /// The mark, or nil from version 7, where an alignment pattern sits under it.
  public let mark: Mark?
  private let drawn: [Bool]

  /// The layout of a symbol's dark modules, `matrix[row][column]`; nil unless it is square and
  /// of a QR code's size.
  public init?(matrix: [[Bool]]) {
    let size = matrix.count
    guard size >= 21, (size - 17) % 4 == 0, matrix.allSatisfy({ $0.count == size }) else {
      return nil
    }
    self.size = size
    version = (size - 17) / 4
    finders = [
      Module(row: 0, column: 0), Module(row: 0, column: size - 7),
      Module(row: size - 7, column: 0),
    ]
    alignments = Self.alignmentCentres(version: version, size: size)

    var cleared: [(x: Double, y: Double, radius: Double)] = []
    if version < 7 {
      var side = Int((Double(size) * 0.3).rounded())
      if side % 2 == 0 { side += 1 }
      let inner = Double(side) - 1.2
      let glyph = inner * 0.92
      let offset = Double(size - side) / 2 + 0.6 + (inner - glyph) / 2
      let scale = glyph / 24
      mark = Mark(offset: offset, scale: scale)
      // Only the modules near a bubble give way, so the empty corners of the mark's diagonal
      // keep their data.
      cleared = Self.markBubbles.map {
        (
          offset + $0.x * scale, offset + $0.y * scale,
          ($0.radius + Self.markStroke / 2) * scale + 1.4
        )
      }
    } else {
      mark = nil
    }

    let alignments = alignments
    func inPattern(_ row: Int, _ column: Int) -> Bool {
      let inFinder =
        (row < 7 || row >= size - 7) && (column < 7 || column >= size - 7)
        && !(row >= size - 7 && column >= size - 7)
      return inFinder
        || alignments.contains { abs(row - $0.row) <= 2 && abs(column - $0.column) <= 2 }
    }
    // The timing patterns and the format information, which a scanner reads before the data and
    // the error correction cannot mend, never give way to the mark.
    func isFunction(_ row: Int, _ column: Int) -> Bool {
      if row == 6 || column == 6 { return true }
      if row == 8 && (column <= 8 || column >= size - 8) { return true }
      if column == 8 && (row <= 8 || row >= size - 8) { return true }
      return false
    }
    var drawn = [Bool](repeating: false, count: size * size)
    for row in 0..<size {
      for column in 0..<size where matrix[row][column] && !inPattern(row, column) {
        let x = Double(column) + 0.5
        let y = Double(row) + 0.5
        let isCleared =
          !isFunction(row, column)
          && cleared.contains {
            ((x - $0.x) * (x - $0.x) + (y - $0.y) * (y - $0.y)).squareRoot() < $0.radius
          }
        drawn[row * size + column] = !isCleared
      }
    }
    self.drawn = drawn
  }

  /// Whether a data module is drawn: dark, outside the finders and alignment patterns, and clear
  /// of the mark. False outside the symbol.
  public func isDrawn(row: Int, column: Int) -> Bool {
    guard row >= 0, column >= 0, row < size, column < size else { return false }
    return drawn[row * size + column]
  }

  /// Every drawn data module, row by row.
  public var drawnModules: [Module] {
    (0..<size).flatMap { row in
      (0..<size).compactMap { isDrawn(row: row, column: $0) ? Module(row: row, column: $0) : nil }
    }
  }

  /// The corners of a drawn module that round, half a module: each where neither neighbour on its
  /// two sides is drawn, so runs and blocks of modules read as single soft shapes.
  public func roundedCorners(row: Int, column: Int) -> Corners {
    let up = isDrawn(row: row - 1, column: column)
    let down = isDrawn(row: row + 1, column: column)
    let left = isDrawn(row: row, column: column - 1)
    let right = isDrawn(row: row, column: column + 1)
    var corners: Corners = []
    if !up && !left { corners.insert(.topLeft) }
    if !up && !right { corners.insert(.topRight) }
    if !down && !right { corners.insert(.bottomRight) }
    if !down && !left { corners.insert(.bottomLeft) }
    return corners
  }

  /// The standard's alignment-pattern table by formula: a line of centres from 6 to size − 7, and
  /// a pattern at every pair of them but the three that would land on a finder.
  static func alignmentCentres(version: Int, size: Int) -> [Module] {
    guard version >= 2 else { return [] }
    let count = version / 7 + 2
    let interval =
      size == 145 ? 26 : Int((Double(size - 13) / Double(2 * count - 2)).rounded(.up)) * 2
    var line = [size - 7]
    for _ in 0..<(count - 2) { line.append(line[line.count - 1] - interval) }
    line.append(6)
    line.reverse()
    let last = line.count - 1
    return line.indices.flatMap { i in
      line.indices.compactMap { j in
        let onFinder = (i == 0 && j == 0) || (i == 0 && j == last) || (i == last && j == 0)
        return onFinder ? nil : Module(row: line[i], column: line[j])
      }
    }
  }
}
