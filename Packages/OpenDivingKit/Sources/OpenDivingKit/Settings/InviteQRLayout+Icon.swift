/// The icon the invite link's code folds into: its three finders as the icon's eyes, and five of
/// its modules from the bottom-right quarter as the five dots beside them. Positions are in a unit
/// square, (0, 0) at the icon's top-left corner.
///
/// The proportions are the system's `qrcode` symbol's, measured from its glyph, so the icon sits
/// in the top bar as one of its own.
extension InviteQRLayout {
  /// An eye's side, of the icon's.
  public static let iconEyeSide = 0.456
  /// An eye's ring, its pupil, and the corners of its outside, its hole and its pupil, each of
  /// the eye's side.
  public static let iconRingWidth = 0.17
  public static let iconPupilSide = 0.25
  public static let iconEyeRadius = 0.23
  public static let iconHoleRadius = 0.04
  public static let iconPupilRadius = 0.02
  /// A dot's side, of the icon's, and its corners, of its own side.
  public static let iconDotSide = 0.115
  public static let iconDotRadius = 0.1

  /// The eyes' top-left corners, in the order of `finders`: top left, top right, bottom left.
  public static let iconEyes: [(x: Double, y: Double)] = [
    (0, 0), (1 - iconEyeSide, 0), (0, 1 - iconEyeSide),
  ]

  /// The dots' top-left corners: a die's five in the quarter the eyes leave, short of its far
  /// edges as the system's symbol has them.
  public static let iconDots: [(x: Double, y: Double)] = {
    let near = 0.572
    let middle = 0.717
    let far = 0.861
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
