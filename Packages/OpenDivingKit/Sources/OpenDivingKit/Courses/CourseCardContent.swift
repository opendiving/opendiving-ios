extension PlainCardContent {
  /// A course's row on More's *Courses* (`CourseCard`): its name with its status, and the dates
  /// and the agency under it, leaving out whichever it lacks. A completed course, most of the
  /// list, wears no status, so the courses that still have something to say stand out.
  public static func course(_ course: CourseRead) -> PlainCardContent {
    PlainCardContent(
      title: course.name,
      badges: course.status == "completed" ? [] : [CoursePageContent.statusBadge(course.status)],
      facts: CoursePageContent.datesAndAgency(course).map { Fact(text: $0) })
  }
}
