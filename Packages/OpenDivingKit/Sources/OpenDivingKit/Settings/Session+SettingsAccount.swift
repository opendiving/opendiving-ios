extension Session {
  /// For as long as a settings screen shows, until the calling task is cancelled: the account
  /// is read when the screen appears and again each time the app returns to the foreground, so
  /// what was changed elsewhere — on the web — shows without a refresh. A read the app starts on
  /// its own waits for a route: with none it is skipped, and a route appearing makes up for it.
  public func followAccountWhileShowing() async {
    var owed = !(await readAccountIfRouted())
    for await moment in connectivity.moments() {
      switch moment {
      case .becameActive: owed = !(await readAccountIfRouted())
      case .routeAppeared where owed: owed = !(await readAccountIfRouted())
      case .routeAppeared: break
      }
    }
  }

  /// True once the read has been made, whatever it answered but a missing route.
  private func readAccountIfRouted() async -> Bool {
    guard case .signedIn = state, connectivity.isRouteAvailable else { return false }
    do {
      try await reloadAccount()
      return true
    } catch {
      return !APIError(error).isUnreachable
    }
  }
}
