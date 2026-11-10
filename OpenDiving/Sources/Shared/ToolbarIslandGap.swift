import SwiftUI

/// Parts the items either side of it into separate islands in the top bar. Before iOS 26 the bar
/// has no islands to part.
struct ToolbarIslandGap: ToolbarContent {
  var placement = ToolbarItemPlacement.topBarTrailing

  var body: some ToolbarContent {
    if #available(iOS 26, *) {
      ToolbarSpacer(.fixed, placement: placement)
    }
  }
}
