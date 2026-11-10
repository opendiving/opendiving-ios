import Foundation
import OpenDivingKit
import Testing

@testable import OpenDiving

/// More's *Courses* and a course's page say what the web says, offline with nothing kept that
/// they show once the server can be reached, and a course's *Log a dive* opens on the course.
@MainActor
struct CourseScreensTests {
  private let server = APIError.http(status: 500, message: "Internal Server Error")

  @Test func aListOrPageNeverShownSaysItShowsOnceTheServerCanBeReached() {
    #expect(CourseListView.failure(.noRoute) == OfflineText.coursesNotShown)
    #expect(CourseDetailView.failure(.noRoute) == OfflineText.courseNotShown)
  }

  @Test func aFailureOnlineSaysTheWebsSentence() {
    #expect(CourseListView.failure(server) == "Failed to load courses. Please try again.")
    #expect(CourseDetailView.failure(server) == server.message)
  }

  @Test func theWordsAreTheWebs() {
    #expect(CourseListView.title == "Courses")
    #expect(
      CourseListView.description == "The training you did, with the dives and cards it produced")
    #expect(CourseListView.emptyTitle == "No courses yet")
    #expect(
      CourseListView.emptyMessage
        == "Add the training you have done to group its dives and cards.")
    #expect(CourseListView.emptyAction == "Add your first course")
    #expect(CourseDetailView.notFound == "Course not found.")
    #expect(CourseDetailView.certificationsTitle == "Certifications from This Course")
    #expect(
      CourseDetailView.certificationsDescription
        == "The cards this training issued. An existing card can name this course from its own form too."
    )
    #expect(CourseDetailView.certificationsEmptyTitle == "No certifications from this course yet")
    #expect(
      CourseDetailView.certificationsEmptyMessage
        == "Add the card this training issued, or name this course from an existing card's form."
    )
    #expect(CourseDetailView.certificationsEmptyAction == "Add the first certification")
  }

  @Test func logADiveOpensTheFormOnTheCourse() {
    let course = UUID()
    #expect(DiveFormMode.course(course).form == .course(course))
  }
}
