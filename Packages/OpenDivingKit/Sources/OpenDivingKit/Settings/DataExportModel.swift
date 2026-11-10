import Foundation
import Observation

/// *Data*'s downloads, and any other screen's that offers one: each export is a direct call,
/// online only, written to a file that is handed to the share sheet and removed once the sheet
/// closes, so the phone keeps no copy. One export runs at a time.
@MainActor
@Observable
public final class DataExportModel {
  /// The export on its way.
  public private(set) var downloading: ExportFormat?
  /// Why the last export saved nothing, until the next one starts.
  public private(set) var failure: (format: ExportFormat, message: String)?
  /// The file waiting in the share sheet.
  public private(set) var shared: ExportedFile?

  @ObservationIgnored private let session: Session
  @ObservationIgnored private let directory: URL
  @ObservationIgnored private var running: Task<Void, Never>?

  /// The files land under `directory`, each in a directory of its own.
  public init(
    session: Session,
    directory: URL = FileManager.default.temporaryDirectory
      .appendingPathComponent("Exports", isDirectory: true)
  ) {
    self.session = session
    self.directory = directory
  }

  /// While an export is on its way or waiting in the share sheet, none starts.
  public var isBusy: Bool { downloading != nil || shared != nil }

  /// Starts ``download(_:)`` in a task ``stop()`` cancels.
  public func start(_ format: ExportFormat) {
    guard !isBusy else { return }
    running = Task { await download(format) }
  }

  /// Fetches `format` into ``shared``. With no route nothing is sent.
  public func download(_ format: ExportFormat) async {
    guard !isBusy else { return }
    failure = nil
    downloading = format
    defer { downloading = nil }
    do {
      let file = try await session.routedClient().export(format, into: directory)
      guard !Task.isCancelled else { return file.remove() }
      shared = file
    } catch is CancellationError {
    } catch {
      guard !Task.isCancelled else { return }
      failure = (format, APIError(error).message)
    }
  }

  /// The share sheet closed: the file goes.
  public func finishSharing() {
    shared?.remove()
    shared = nil
  }

  /// The screen offering the export is gone: the export on its way is cut off and the file
  /// waiting is removed.
  public func stop() {
    running?.cancel()
    running = nil
    finishSharing()
  }
}
