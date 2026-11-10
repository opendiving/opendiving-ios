extension PlainCardContent {
  /// A contact's card on More's *Contacts*: its name with a badge per role, in the order the API
  /// keeps them, and its city under it.
  public static func contact(_ contact: ContactRead) -> PlainCardContent {
    let city = contact.address?.city.flatMap { $0.isEmpty ? nil : $0 }
    return PlainCardContent(
      title: contact.name, badges: contact.roles.map { Badge(RecordSheetText.contactRole($0)) },
      facts: city.map { [Fact(text: $0)] } ?? [])
  }
}
