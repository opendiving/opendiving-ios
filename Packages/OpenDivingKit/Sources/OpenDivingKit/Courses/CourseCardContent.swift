extension PlainCardContent {
  /// A course's row on More's *Courses* (`CourseCard`): its name with its status, and the dates
  /// and the agency under it, leaving out whichever it lacks.
  public static func course(_ course: CourseRead) -> PlainCardContent {
    PlainCardContent(
      title: course.name, badges: [CoursePageContent.statusBadge(course.status)],
      facts: CoursePageContent.datesAndAgency(course).map { Fact(text: $0) })
  }
}
