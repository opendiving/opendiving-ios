import Foundation

// A record created on the phone is listed in its picker from the moment it is queued, as the
// row the server would answer for it, under its local ref — and under the server's once its
// create lands, until the next refresh brings the server's own row.

extension DiveSiteCreate {
  func lookupRow(_ ref: RecordRef) -> DiveSiteLookupItem {
    DiveSiteLookupItem(
      ref: ref, name: name,
      location: location.map {
        LocationRead(
          name: $0.name, latitude: $0.latitude, longitude: $0.longitude, bboxSouth: $0.bboxSouth,
          bboxNorth: $0.bboxNorth, bboxWest: $0.bboxWest, bboxEast: $0.bboxEast)
      }, waterType: waterType, altitude: altitude, entryTypes: entryTypes)
  }
}

extension TripCreate {
  func lookupRow(_ ref: RecordRef) -> TripLookupItem {
    TripLookupItem(ref: ref, name: name, people: people)
  }
}

extension PersonCreate {
  func lookupRow(_ ref: RecordRef) -> PersonLookupItem {
    PersonLookupItem(ref: ref, name: name, username: username)
  }
}

extension CourseCreate {
  func lookupRow(_ ref: RecordRef) -> CourseLookupItem {
    CourseLookupItem(ref: ref, name: name, contact: contact, people: people)
  }
}

extension ContactCreate {
  func lookupRow(_ ref: RecordRef) -> ContactLookupItem {
    ContactLookupItem(
      ref: ref, name: name,
      address: address.map {
        ContactAddressRead(
          street: $0.street, city: $0.city, postcode: $0.postcode, region: $0.region,
          country: $0.country)
      })
  }
}

extension GearItemCreate {
  func lookupRow(_ ref: RecordRef) -> GearItemLookupItem {
    GearItemLookupItem(
      ref: ref, name: name, brand: brand, type: type, rented: rented, volume: volume,
      workingPressure: workingPressure, material: material)
  }
}

extension GearItemLookupItem {
  var info: GearItemInfo {
    GearItemInfo(
      ref: ref, name: name, brand: brand, type: type, rented: rented, isArchived: isArchived,
      volume: volume, workingPressure: workingPressure, material: material)
  }
}

extension GearSetCreate {
  /// The set's items as `known` names them; an item the phone has no row for is left out.
  func row(_ ref: RecordRef, known: [RecordRef: GearItemInfo]) -> GearSetRow {
    GearSetRow(ref: ref, name: name, weight: weight, items: gearItems.compactMap { known[$0] })
  }
}

extension GearSetRow {
  func applying(_ update: GearSetUpdate, known: [RecordRef: GearItemInfo]) -> GearSetRow {
    var row = self
    if let name = update.name { row.name = name }
    row.weight = update.weight.applied(to: weight)
    if let refs = update.gearItems {
      let mine = Dictionary(items.map { ($0.ref, $0) }, uniquingKeysWith: { a, _ in a })
      row.items = refs.compactMap { mine[$0] ?? known[$0] }
    }
    return row
  }
}
