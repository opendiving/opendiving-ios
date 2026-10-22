# OpenDiving iOS

**The iPhone app for [OpenDiving](https://github.com/opendiving/opendiving) — an open-source,
self-hostable dive log.**

> **In development.** The app builds and runs, and is being filled in screen by screen; there is
> nothing in the App Store and no TestFlight. To try it, build it onto your own phone from source —
> [CONTRIBUTING.md](CONTRIBUTING.md) says how, with a free Apple Account.

## What it is

A client of *your* OpenDiving server — the one you run, or [opendiving.app](https://opendiving.app)
— with no cloud of its own. The first version, being built now, asks where the server is, signs in
with a code sent to your email, and shows your logbook read-only: dives with their profile charts,
trips and dive sites, in the units your account uses. Logging and editing stay on the web.

## Why an app

The [web app](https://github.com/opendiving/opendiving-web) covers logging, trips, gear and
dive-profile charts. The phone is where an app can do what a browser can't:

- **C-cards in your pocket** — your check-in sheet, with every certification card, kept on the
  phone so it opens at the dive shop counter with no signal and after you have signed out. This is
  the first of the three to arrive, and it is being built now.
- **Bluetooth download from dive computers** — pull dives straight off the wrist, no cables, no
  vendor cloud. Later.
- **Offline-first logging** — dives happen on boats and islands without signal; log now, sync to
  your own server afterwards. Later.

## Stack

SwiftUI on iOS 18 and later, over `OpenDivingKit`, a Swift package holding everything that is not
a view. It talks to the [opendiving-api](https://github.com/opendiving/opendiving-api) REST API
with the same passwordless sign-in as the web app, by email code.

## Related repositories

| | |
|---|---|
| [opendiving](https://github.com/opendiving/opendiving) | **The front door** — install, docs, and the release; start here to self-host |
| [opendiving-api](https://github.com/opendiving/opendiving-api) | FastAPI backend |
| [opendiving-web](https://github.com/opendiving/opendiving-web) | Next.js web app |

## License

Licensed under the [Apache License 2.0](LICENSE) — permissive on purpose, so
third-party clients for the OpenDiving API are welcome. The server stays
AGPL-licensed; the data stays yours.
