import Foundation
import Observation

/// The renumber sheet, the web's *Renumber Dives* dialog: the number to start at and the first
/// day, the server's dry run over them, and the renumber it previewed. A preview is kept with
/// the fields it answered, so the changes listed and the renumber *Renumber* writes are always
/// those for what the fields say now.
@MainActor
@Observable
public final class RenumberModel {
  /// What the fields say: the start number, nil while the box holds none in range.
  public struct Inputs: Hashable, Sendable {
    public let startAt: Int?
    public let fromDate: CalendarDate?
  }

  private enum Outcome: Equatable {
    case result(DiveRenumberResult)
    case failed(String)
  }

  public var startAtText: String
  public var fromDate: CalendarDate?
  public private(set) var isApplying = false
  /// Why the last *Renumber* wrote nothing.
  public private(set) var applyError: String?

  private var lastPreview: (inputs: Inputs, outcome: Outcome)?

  @ObservationIgnored private let session: Session
  @ObservationIgnored private let offsetMinutes: Int
  @ObservationIgnored private let debounce: Duration

  /// `debounce` makes typing *1*, *0*, *2* one preview rather than three.
  public init(
    session: Session, defaults: RenumberDefaults = .wholeLog,
    offsetMinutes: Int = RenumberScope.phoneOffsetMinutes(),
    debounce: Duration = .milliseconds(350)
  ) {
    self.session = session
    self.offsetMinutes = offsetMinutes
    self.debounce = debounce
    startAtText = String(defaults.startAt)
    fromDate = defaults.fromDate
  }

  public var inputs: Inputs {
    let number = Int(startAtText.trimmingCharacters(in: .whitespaces))
    let inRange = number.map { (1...DiveFormBounds.integerMax).contains($0) } ?? false
    return Inputs(startAt: inRange ? number : nil, fromDate: fromDate)
  }

  /// The preview for what the fields say now, or nil while it is on its way.
  private var current: Outcome? {
    guard let lastPreview, lastPreview.inputs == inputs else { return nil }
    return lastPreview.outcome
  }

  public var isWorking: Bool { inputs.startAt != nil && current == nil }

  /// The sentence over the changes, or in their place.
  public var statusLine: String {
    guard inputs.startAt != nil else { return DiveNumberingText.startAtRange }
    switch current {
    case nil: return DiveNumberingText.working
    case .failed(let message): return message
    case .result(let result) where result.changes.isEmpty:
      return result.divesInScope == 0
        ? DiveNumberingText.nothingInScope : DiveNumberingText.alreadyNumbered
    case .result(let result): return DiveNumberingText.changeCount(result)
    }
  }

  /// Every dive the renumber moves, in date order: a list that stopped at a few would hide the
  /// rows a diver checks against a paper logbook.
  public var changes: [DiveRenumberChange] {
    guard case .result(let result) = current else { return [] }
    return result.changes
  }

  public var canApply: Bool { !isApplying && !changes.isEmpty }

  /// The dry run for what the fields say now, after the debounce. The sheet runs it in a task
  /// keyed by ``inputs``, which a change to the fields cancels.
  public func preview() async {
    let inputs = inputs
    guard let startAt = inputs.startAt else { return }
    try? await Task.sleep(for: debounce)
    guard !Task.isCancelled else { return }
    let outcome: Outcome
    do {
      let client = try session.routedClient()
      outcome = .result(
        try await client.renumberDives(request(startAt, inputs.fromDate, dryRun: true)))
    } catch {
      // A renumber that would number the last dive past the column is a 422 with a sentence of
      // its own; any other failure is about the connection.
      if case .http(422, let message?) = APIError(error) {
        outcome = .failed(message)
      } else {
        outcome = .failed(DiveNumberingText.previewFailed)
      }
    }
    guard !Task.isCancelled else { return }
    lastPreview = (inputs, outcome)
  }

  /// *Renumber*: writes the renumber the sheet lists, and tells every list over the account,
  /// whose dives now carry other numbers. The count of dives renumbered, or nil with
  /// ``applyError`` saying why.
  public func apply() async -> Int? {
    guard canApply, let startAt = inputs.startAt else { return nil }
    isApplying = true
    applyError = nil
    defer { isApplying = false }
    do {
      let result = try await session.routedClient().renumberDives(
        request(startAt, inputs.fromDate, dryRun: false))
      if let stores = AccountStores.current(session) {
        OutboxHub.hub(for: stores.directory).listsChanged()
      }
      return result.changes.count
    } catch {
      applyError = APIError(error).message
      return nil
    }
  }

  private func request(_ startAt: Int, _ fromDate: CalendarDate?, dryRun: Bool)
    -> DiveRenumberRequest
  {
    DiveRenumberRequest(
      startAt: startAt,
      fromStartTime: fromDate.map { RenumberScope.start(of: $0, offsetMinutes: offsetMinutes) },
      dryRun: dryRun)
  }
}
