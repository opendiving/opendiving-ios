import Foundation

/// The fonts a style's own labels use, which a layer the app adds must name to draw text: a
/// style's glyphs serve only the font stacks it was built with.
public enum MapStyleFonts {
  /// The first `text-font` a layer of `styleJSON` names as a list of font names; nil where none
  /// does, or the font is an expression.
  public static func textFont(in styleJSON: String) -> [String]? {
    guard let data = styleJSON.data(using: .utf8),
      let style = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let layers = style["layers"] as? [[String: Any]]
    else { return nil }
    for layer in layers {
      guard let layout = layer["layout"] as? [String: Any],
        let fonts = layout["text-font"] as? [Any], !fonts.isEmpty
      else { continue }
      let names = fonts.compactMap { $0 as? String }
      // `["literal", [...]]` and other expressions name no stack this reads.
      if names.count == fonts.count, names.first != "literal" { return names }
    }
    return nil
  }
}
