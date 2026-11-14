import Foundation

/// The upload: each archive of the loaded account, oldest first, with `POST /imports?apply=true`
/// under the archive's own key, by a running app whose account has loaded — loaded first, quietly,
/// where this process has not.
///
/// - An applied import: the archive leaves the phone, its dives join what the server answered
///   for, and the notification says what was imported.
/// - A pending import, a server that cannot apply in one request: that import, which the
///   upload made, is discarded and the archive kept as refused. A pending answer is never taken
///   for a written dive.
/// - A 410: the import was made and has since been deleted, so the archive leaves and nothing
///   is said.
/// - Any other 4xx but a 409 and a 429: kept as refused, and not sent again by itself.
/// - A 409, a 429, a 5xx or no answer: tried again at the next occasion, as the outbox treats
///   them; with no route, iOS is left a request to the server whose completion wakes the app.
/// - Signed out, the session's 401 among it: the archive waits for a sign-in to its account.
///
/// The diver is told at most once that an archive's dives were downloaded and wait, and at most
/// once that they were imported: a repeat under the key answers the import the first attempt
/// made.
extension DiveComputerEngine {
  /// An occasion to upload: a walk's end, a launch, a route, a sign-in, the account loading,
  /// iOS completing the request left with it.
  public func upload() {
    guard uploading == nil else {
      uploadAgain = true
      return
    }
    uploading = Task {
      repeat {
        uploadAgain = false
        await uploadAll()
      } while uploadAgain
      uploading = nil
    }
  }

  private func uploadAll() async {
    // What a walk kept before a load it outlasted moves to the account the load named.
    if session.accountLoaded { settleMarks() }
    guard let origin = session.state.origin, let (kept, _) = keeping() else { return }
    guard case .signedIn = session.state else {
      announceSignedOut()
      return
    }
    // Before the account's load, which with no route would wait for one and fail: what waits is
    // said and iOS asked to wake the app, whatever this process has loaded.
    guard session.connectivity.isRouteAvailable else {
      waitForRoute(DownloadStore(store: session.store, origin: origin, account: kept), origin)
      return
    }
    // One assertion for the whole pass, the load included: a process iOS woke for this has no
    // other time.
    let token = await session.background.begin(name: "Importing the dives just downloaded")
    defer { Task { [session] in await session.background.end(token) } }
    if !session.accountLoaded { await loadAccount() }
    guard case .signedIn = session.state else {
      announceSignedOut()
      return
    }
    guard session.accountLoaded, let user = session.user else { return }
    settleMarks()
    let downloads = DownloadStore(store: session.store, origin: origin, account: user.uuid)
    defer { reload() }
    for archive in downloads.archives() where archive.refusal == nil {
      guard session.connectivity.isRouteAvailable else {
        waitForRoute(downloads, origin)
        return
      }
      guard let client = try? session.requireClient() else { return }
      guard await send(archive, downloads, client, origin: origin) else { return }
    }
  }

  /// One archive's upload; whether the next goes after it.
  private func send(
    _ archive: DownloadArchive, _ downloads: DownloadStore, _ client: APIClient,
    origin: ServerOrigin
  ) async -> Bool {
    let computer = archive.summary.computers.first?.title ?? ""
    do {
      let answer = try await client.importAtOnce(
        files: [ImportFile(file: downloads.url(for: archive), filename: archive.filename)],
        idempotencyKey: archive.key)
      guard answer.isApplied else {
        try? await client.deleteImport(answer.uuid, status: "pending")
        refuse(archive, .notAppliedAtOnce, in: downloads)
        return true
      }
      try? downloads.deliver(archive.dives, of: archive.record)
      downloads.remove(archive)
      if let notice = DiveComputerNotice.imported(answer, from: computer, units: session.units) {
        notifier?.post(notice)
      }
      return true
    } catch let error as APIError {
      switch error {
      case .http(410, _):
        downloads.remove(archive)
        return true
      case .http(let status, _) where status == 409 || status == 429 || status >= 500:
        return false
      case .http(_, let message):
        refuse(archive, .server(message: message), in: downloads)
        return true
      case .signedOut:
        announceSignedOut()
        return false
      case .unreachable:
        waitForRoute(downloads, origin)
        return false
      case .secretStore, .notAnInstance, .unreadableResponse:
        return false
      }
    } catch {
      return false
    }
  }

  private func refuse(
    _ archive: DownloadArchive, _ refusal: DownloadArchive.Refusal, in downloads: DownloadStore
  ) {
    var refused = archive
    refused.refusal = refusal
    try? downloads.save(refused)
  }

  /// No route: each archive not yet announced says its dives wait, and, where any waits, iOS is
  /// left the request that wakes the app once there is one. With a route the server itself did
  /// not answer, which is neither *No internet* nor anything a wake would mend: the next
  /// occasion tries again.
  private func waitForRoute(_ downloads: DownloadStore, _ origin: ServerOrigin) {
    guard !session.connectivity.isRouteAvailable,
      downloads.archives().contains(where: { $0.refusal == nil })
    else { return }
    announce(downloads) { archive, computer in
      .noInternet(dives: archive.summary.dives, from: computer, id: archive.id)
    }
    wake?.leave(for: origin)
  }

  /// Nobody signed in: the archives of the account dives are kept for say they wait for a
  /// sign-in.
  private func announceSignedOut() {
    guard let (account, _) = keeping(), let origin = session.state.origin else { return }
    let downloads = DownloadStore(store: session.store, origin: origin, account: account)
    announce(downloads) { archive, computer in
      .signedOut(dives: archive.summary.dives, from: computer, id: archive.id)
    }
  }

  private func announce(
    _ downloads: DownloadStore,
    _ notice: (DownloadArchive, String) -> DiveComputerNotice
  ) {
    for archive in downloads.archives() where !archive.announced && archive.refusal == nil {
      var announced = archive
      announced.announced = true
      guard (try? downloads.save(announced)) != nil else { continue }
      notifier?.post(notice(archive, archive.summary.computers.first?.title ?? ""))
    }
  }
}
