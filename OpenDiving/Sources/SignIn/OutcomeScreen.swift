import OpenDivingKit
import SwiftUI

/// A code redeemed into something only the web can finish: an account whose sign-up was never
/// completed, or one scheduled for deletion.
struct OutcomeScreen: View {
  let title: String
  let systemImage: String
  let message: String
  let origin: ServerOrigin?
  let back: () -> Void

  var body: some View {
    ContentUnavailableView {
      Label(title, systemImage: systemImage)
    } description: {
      Text(message)
    } actions: {
      if let origin {
        Link("Open " + origin.description, destination: origin.url)
          .buttonStyle(.borderedProminent)
      }
      Button("Back", action: back)
        .buttonStyle(.bordered)
    }
    .navigationTitle("Sign in")
  }
}

#Preview("Onboarding") {
  let origin = ServerOrigin("https://opendiving.app")
  NavigationStack {
    OutcomeScreen(
      title: "Finish signing up on the web", systemImage: "person.crop.circle.badge.questionmark",
      message: SignInFlow.onboardingMessage(email: "sam@example.com", origin: origin),
      origin: origin
    ) {}
  }
}

#Preview("Deletion pending") {
  let origin = ServerOrigin("https://opendiving.app")
  NavigationStack {
    OutcomeScreen(
      title: "This account is scheduled for deletion", systemImage: "trash",
      message: SignInFlow.deletionMessage(
        email: "sam@example.com", purgeAfter: "Nov 21, 2026", origin: origin),
      origin: origin
    ) {}
  }
}
