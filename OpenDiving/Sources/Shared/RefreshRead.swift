/// What a pull runs. SwiftUI cancels a refresh's task whenever the view it is applied to draws
/// again — the spinner's own state, one list's page landing beside another's, the account
/// reloading under the screen — which would cut short every read the pull starts. The read runs
/// in a task of its own instead, and the pull waits for it, so the spinner stays until it answers.
enum RefreshRead {
  static func run(_ action: @escaping @MainActor () async -> Void) async {
    await Task { await action() }.value
  }
}
