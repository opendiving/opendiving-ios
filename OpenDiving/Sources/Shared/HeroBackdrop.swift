import Foundation
import OpenDivingKit

/// What a ``HeroView`` draws behind its details: a map of the record's places, or a photo of
/// the record — a species' — with the map's water and `placeholder` where it has none.
enum HeroBackdrop: Hashable {
  case map
  case photo(Data?, placeholder: OpenDivingKit.Icon)
}
