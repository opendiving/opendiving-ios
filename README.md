# OpenDiving iOS

Native SwiftUI client for [OpenDiving](https://github.com/opendiving/opendiving-web) — a
self-hosted, open-source dive log.

**Status: early scaffold, deliberately parked.** What exists today is the foundation, not a
logbook: passwordless sign-in against the OpenDiving API (magic-link flow), Keychain token
storage, and the API client plumbing. There are no dive views yet.

The web app is the primary client while the server and API settle — it's responsive and works
fine on a phone. This app's turn comes after the server story is complete (full export,
one-command self-hosting, broader importers); when it does, the direction is offline-first
logging against your own instance, and eventually Bluetooth downloads from dive computers.

## License

[AGPL-3.0](LICENSE), same as the rest of OpenDiving.
