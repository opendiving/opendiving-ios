extension PlainCardContent {
  /// A person's row on More's *People*: their name, and under it the connected account's username
  /// and how many dives name them.
  public static func person(_ person: PersonRead) -> PlainCardContent {
    PlainCardContent(
      title: person.name,
      facts: (PersonPageContent.username(person).map { [Fact(text: $0)] } ?? [])
        + [Fact(text: DiveDetailText.countNoun(person.diveCount, "dive"))])
  }

}
