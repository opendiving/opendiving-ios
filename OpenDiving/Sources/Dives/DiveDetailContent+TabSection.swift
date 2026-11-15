import OpenDivingKit

nonisolated extension DiveDetailContent.Tab: TabSection {
  var title: String {
    switch self {
    case .info: "Info"
    case .data: "Data"
    case .gear: "Gear"
    case .marineLife: "Marine life"
    }
  }
}
