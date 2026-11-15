import Foundation
import OpenDivingKit

/// What a ``HeroView`` draws behind its details: a map of the record's places, a photo of
/// the record — a species' — with the map's water and `placeholder` where it has none, or, for a
/// record of a kind that has neither, nothing but the water.
enum HeroBackdrop: Hashable {
  case map
  case photo(Data?, placeholder: OpenDivingKit.Icon)
  case plain
}
