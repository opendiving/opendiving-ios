import OpenDivingKit

/// A stub session for the Authentication previews, answering the three lists as the API would.
enum AuthenticationPreviewData {
  static var session: Session {
    Session.stub(
      transport: StubTransport(routes: [
        "GET user/passkeys": .json(passkeys),
        "GET user/sessions": .json(sessions),
        "GET user/api-keys": .json(keys),
      ]))
  }

  static let passkeys =
    #"[{"uuid":"019a1f2e-3c4d-7a5b-8c6d-7e8f9a0b1c2d","name":"iPhone","backed_up":true,"#
    + #""created_at":"2026-10-01T09:12:44Z","last_used_at":"2026-11-02T18:40:05Z"},"#
    + #"{"uuid":"019a1f2e-3c4d-7a5b-8c6d-7e8f9a0b1c2e","name":"YubiKey","backed_up":false,"#
    + #""created_at":"2026-10-05T07:00:00Z","last_used_at":null}]"#

  static let sessions =
    #"[{"uuid":"019a2b3c-4d5e-7f60-8a1b-2c3d4e5f6a71","created_at":"2026-10-23T10:30:00Z","#
    + #""last_used_at":"2026-11-09T21:02:00Z","ip":"198.51.100.20","#
    + #""user_agent":"OpenDiving-iOS/1.4 (iOS 18.6; iPhone)","idle_timeout":"extended","#
    + #""current":true},{"uuid":"019a2b3c-4d5e-7f60-8a1b-2c3d4e5f6a70","#
    + #""created_at":"2026-11-01T08:00:00Z","last_used_at":"2026-11-09T22:14:31Z","#
    + #""ip":"203.0.113.7","user_agent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"#
    + #" AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36","#
    + #""idle_timeout":"standard","current":false}]"#

  static let keys =
    #"[{"uuid":"019a3c4d-5e6f-7081-9a2b-3c4d5e6f7a80","name":"laptop","prefix":"odk_3fA9xQ2b","#
    + #""scope":"read","created_at":"2026-09-01T10:00:00Z","#
    + #""last_used_at":"2026-11-08T07:31:00Z","expires_at":"2026-10-01T10:00:00Z"}]"#
}
