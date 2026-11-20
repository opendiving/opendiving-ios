/// What a course's page shows under its head.
nonisolated enum CourseSection: TabSection {
  case info, certifications, dives

  var title: String {
    switch self {
    case .info: "Info"
    case .certifications: "Certifications"
    case .dives: "Dives"
    }
  }
}
