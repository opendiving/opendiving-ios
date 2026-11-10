import Foundation

extension PagedList where Item == CertificationRead {
  /// More's *Certifications*, newest certified first, over the account's copy of the pages it has
  /// shown; with no route it asks for nothing.
  public static func certifications(_ session: Session) -> PagedList<CertificationRead> {
    PagedList(session: session, cache: .certifications, routed: true) {
      client, page, itemsPerPage in
      try await client.certifications(page: page, itemsPerPage: itemsPerPage)
    }
  }
}
