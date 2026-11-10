import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

extension APIClient {
  // MARK: - The account's pictures

  /// `PUT /user/{kind}`: `data` is kept as the picture's original, and what every screen shows
  /// is rendered from it through `crop`, which the form field carries as JSON.
  @discardableResult
  public func uploadPicture(
    _ kind: PictureKind, data: Data, filename: String, type: PictureFileType, crop: PictureCrop
  ) async throws -> PictureRead {
    let parts = [
      MultipartPart(
        name: "file", filename: filename, contentType: type.rawValue, content: .data(data)),
      MultipartPart.field("crop", String(decoding: try Self.json(crop), as: UTF8.self)),
    ]
    return try await authorizedDecoded(
      PictureRead.self, Call(method: "PUT", path: "user/\(kind.rawValue)", parts: parts))
  }

  /// `PATCH /user/{kind}`: a new crop over the original the server holds, with no upload. A 404
  /// when it holds none, a 409 when the picture changed while this rendered.
  @discardableResult
  public func adjustPicture(_ kind: PictureKind, crop: PictureCrop) async throws -> PictureRead {
    try await authorizedDecoded(
      PictureRead.self,
      Call(
        method: "PATCH", path: "user/\(kind.rawValue)",
        body: Self.json(PictureCropRequest(crop: crop))))
  }

  /// `POST /user/portrait/from-avatar`: the profile picture's original becomes the portrait's
  /// too, under keys of its own, at `crop`. A 404 while the profile picture holds no original.
  @discardableResult
  public func copyAvatarToPortrait(crop: PictureCrop) async throws -> PictureRead {
    try await authorizedDecoded(
      PictureRead.self,
      Call(
        method: "POST", path: "user/portrait/from-avatar",
        body: Self.json(PictureCropRequest(crop: crop))))
  }

  /// `DELETE /user/{kind}`: the picture and its original. A 404 when there was none.
  public func removePicture(_ kind: PictureKind) async throws {
    try await authorizedChecked(Call(method: "DELETE", path: "user/\(kind.rawValue)"))
  }

  /// `GET /user/{kind}/original?v=`, `version` being the account's original digest: the file the
  /// picture is rendered from, as uploaded less its metadata, for adjusting its crop.
  public func pictureOriginal(_ kind: PictureKind, version: String) async throws -> FetchedBytes {
    let (data, response) = try await authorized(
      Call(
        path: "user/\(kind.rawValue)/original", query: [URLQueryItem(name: "v", value: version)]))
    try check(data, response)
    return FetchedBytes(data: data, response: response)
  }
}
