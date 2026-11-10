extension PlainCardContent {
  /// A person's card on More's *People*: their name, the linked account's username under it, and
  /// how many dives name them.
  public static func person(_ person: PersonRead) -> PlainCardContent {
    PlainCardContent(
      title: person.name, facts: PersonPageContent.username(person).map { [Fact(text: $0)] } ?? [],
      figures: [Figure(label: "Dives", value: String(person.diveCount))])
  }

}
