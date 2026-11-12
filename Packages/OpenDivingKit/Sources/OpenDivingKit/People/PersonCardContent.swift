extension PlainCardContent {
  /// A person's card on More's *People*: their name, and under it the linked account's username
  /// and how many dives name them.
  public static func person(_ person: PersonRead) -> PlainCardContent {
    PlainCardContent(
      title: person.name,
      facts: (PersonPageContent.username(person).map { [Fact(text: $0)] } ?? [])
        + [Fact(text: DiveDetailText.countNoun(person.diveCount, "dive"))])
  }

}
