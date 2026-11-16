/// The icon the invite link's code folds into: its three finders as the icon's eyes, and five of
/// its modules from the bottom-right quarter as the five dots beside them. Positions are in a unit
/// square, (0, 0) at the icon's top-left corner.
extension InviteQRLayout {
  /// An eye's side, of the icon's.
  public static let iconEyeSide = 0.45
  /// A dot's side, of the icon's.
  public static let iconDotSide = 0.13

  /// The eyes' top-left corners, in the order of `finders`: top left, top right, bottom left.
  public static let iconEyes: [(x: Double, y: Double)] = [
    (0, 0), (1 - iconEyeSide, 0), (0, 1 - iconEyeSide),
  ]

  /// The dots' top-left corners: a die's five, filling the quarter the eyes leave.
  public static let iconDots: [(x: Double, y: Double)] = {
    let near = 1 - iconEyeSide
    let far = 1 - iconDotSide
    let middle = (near + far) / 2
    return [(near, near), (far, near), (middle, middle), (near, far), (far, far)]
  }()

  /// The drawn module that becomes each of `iconDots`, the nearest to where that dot sits on the
  /// symbol, from the symbol's bottom-right quarter and no module twice; nil for a dot the quarter
  /// has no drawn module left for.
  public var iconDotModules: [Module?] {
    let half = size / 2
    var candidates = drawnModules.filter { $0.row >= half && $0.column >= half }
    return Self.iconDots.map { dot in
      let row = (dot.y + Self.iconDotSide / 2) * Double(size) - 0.5
      let column = (dot.x + Self.iconDotSide / 2) * Double(size) - 0.5
      let distance = { (module: Module) in
        let dy = Double(module.row) - row
        let dx = Double(module.column) - column
        return dx * dx + dy * dy
      }
      guard
        let index = candidates.indices.min(by: {
          distance(candidates[$0]) < distance(candidates[$1])
        })
      else { return nil }
      return candidates.remove(at: index)
    }
  }
}
