import Foundation

/// Where one recording's profile stands for the chart drawing it.
public enum ProfileLoad: Hashable, Sendable {
  case loading
  case loaded(RecordingProfileRead)
  /// A 404, in the API's own words: the recording has no profile, and asking again would
  /// fail again.
  case missing(String)
  /// Anything else that went wrong, offered again as *Try again*.
  case failed(String)

  /// `GET /dive/{uuid}/recording/{rid}/profile`, as the chart shows its outcome. Nil
  /// `client` is a signed-out session.
  public static func fetch(dive: UUID, recording: UUID, from client: APIClient?) async
    -> ProfileLoad
  {
    do {
      guard let client else { throw APIError.signedOut }
      switch try await client.profile(dive: dive, recording: recording, etag: nil) {
      case .fetched(let profile, _):
        return .loaded(profile)
      case .notModified:
        // Unreachable: nothing was sent to be not-modified against.
        return .failed(APIError.unreadableResponse("304 without a stored copy").message)
      }
    } catch {
      let error = APIError(error)
      if case .http(404, _) = error { return .missing(error.message) }
      return .failed(error.message)
    }
  }
}
