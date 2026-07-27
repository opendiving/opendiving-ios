import SwiftUI

@main
struct OpenDivingApp: App {
    @State private var auth = AuthManager()

    var body: some Scene {
        WindowGroup {
            Group {
                if auth.isLoading {
                    ProgressView()
                } else if auth.isAuthenticated {
                    // Placeholder - swap for your real dashboard/tab view next.
                    VStack(spacing: 12) {
                        Text("Welcome, \(auth.currentUser?.name ?? "")!")
                            .font(.title2)
                        Button("Sign Out") { auth.signOut() }
                    }
                } else {
                    SignInView()
                }
            }
            .environment(auth)
            .task { await auth.bootstrap() }
        }
    }
}
