import Foundation
import Observation

/// What the site finder's map draws: every Commons record with a pin, and the diver's own and
/// saved sites over them.
///
/// The Commons document is one for every account on the server, kept in the server's directory
/// with its `ETag` and asked for again once per launch, so a held copy draws at once and offline
/// and an unchanged one costs a 304. The diver's points are the account's, kept in its cache and
/// read again whenever the finder appears.
@MainActor
@Observable
public final class DiveSitePointsModel {
  public private(set) var commons: CommonsDiveSitePoints?
  public private(set) var yours: [DiveSitePoint] = []

  @ObservationIgnored private let session: Session
  /// The servers whose Commons document this launch has asked for.
  private static var askedCommons: Set<ServerOrigin> = []

  public init(session: Session) {
    self.session = session
  }

  /// The held points at once, then the server's.
  public func load() async {
    showHeld()
    async let commons: Void = fetchCommons()
    async let yours: Void = fetchYours()
    _ = await (commons, yours)
  }

  /// The point of `uuid`, the diver's before the Commons', as the map's top layer is.
  public func point(_ uuid: UUID) -> SiteFinderPoint? {
    if let mine = yours.first(where: { $0.uuid == uuid }) {
      let credit = mine.isCommons ? commonsCredit(uuid) : nil
      return SiteFinderPoint(
        uuid: mine.uuid, name: mine.name, latitude: mine.latitude, longitude: mine.longitude,
        isCommons: mine.isCommons, saved: true, credit: credit)
    }
    guard let commons, let record = commons.points.first(where: { $0.uuid == uuid }) else {
      return nil
    }
    return SiteFinderPoint(
      uuid: record.uuid, name: record.name, latitude: record.latitude,
      longitude: record.longitude, isCommons: true, saved: false, credit: commons.credit(record))
  }

  private func commonsCredit(_ uuid: UUID) -> String? {
    guard let commons, let record = commons.points.first(where: { $0.uuid == uuid }) else {
      return nil
    }
    return commons.credit(record)
  }

  private func showHeld() {
    if commons == nil, let file = commonsFile, let data = try? Data(contentsOf: file.body) {
      commons = try? CommonsDiveSitePoints.decode(data)
    }
    if yours.isEmpty, let held = AccountStores.current(session)?.cache.diveSitePoints {
      yours = held.value
    }
  }

  private func fetchCommons() async {
    guard let origin = session.state.origin, !Self.askedCommons.contains(origin),
      let file = commonsFile, let client = try? session.routedClient()
    else { return }
    let etag = commons == nil ? nil : try? String(contentsOf: file.etag, encoding: .utf8)
    guard let answer = try? await client.commonsDiveSitePoints(etag: etag) else { return }
    Self.askedCommons.insert(origin)
    guard case .fetched(let data, let newTag) = answer,
      let document = try? CommonsDiveSitePoints.decode(data)
    else { return }
    commons = document
    try? FileManager.default.createDirectory(
      at: file.body.deletingLastPathComponent(), withIntermediateDirectories: true)
    try? data.write(to: file.body, options: .atomic)
    if let newTag {
      try? newTag.write(to: file.etag, atomically: true, encoding: .utf8)
    } else {
      try? FileManager.default.removeItem(at: file.etag)
    }
  }

  private func fetchYours() async {
    let stores = AccountStores.current(session)
    guard let client = try? session.routedClient(),
      let answer = try? await client.diveSitePoints()
    else { return }
    yours = answer.points
    cacheForAnswer(fetchedUnder: stores, session: session)?.writeDiveSitePoints(answer.points)
  }

  /// Where the active server's Commons document is kept.
  private var commonsFile: (body: URL, etag: URL)? {
    guard let origin = session.state.origin else { return nil }
    let folder = session.store.directory(for: origin)
      .appendingPathComponent("SiteFinder", isDirectory: true)
    return (
      folder.appendingPathComponent("commons-points.json"),
      folder.appendingPathComponent("commons-points.etag")
    )
  }

  /// Forgets which servers were asked, for a test standing for a new launch.
  static func forgetAsked() {
    askedCommons = []
  }
}
