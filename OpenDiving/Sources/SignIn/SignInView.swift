import OpenDivingKit
import SwiftUI

/// Choosing a server and signing in with an email code. Placeholder.
struct SignInView: View {
  var body: some View {
    NavigationStack {
      EmptyOrErrorView(
        status: .empty(
          systemImage: "person.crop.circle", title: "Sign in", message: "Not built yet.")
      )
      .navigationTitle("Sign in")
    }
  }
}

#Preview {
  SignInView()
}
