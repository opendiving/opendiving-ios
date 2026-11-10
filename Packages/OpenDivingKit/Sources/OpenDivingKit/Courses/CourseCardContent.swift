extension PlainCardContent {
  /// A course's card on More's *Courses* (`CourseCard`): its name with its status, and the agency
  /// and the dates under it, leaving out whichever it lacks.
  public static func course(_ course: CourseRead) -> PlainCardContent {
    PlainCardContent(
      title: course.name, badges: [CoursePageContent.statusBadge(course.status)],
      facts: CoursePageContent.agencyAndDates(course).map { Fact(text: $0) })
  }
}
