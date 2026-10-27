# OpenDiving iOS

**The iPhone app for [OpenDiving](https://github.com/opendiving/opendiving) — an open-source,
self-hostable dive log.**

> **In development.** The app builds, runs, reads your logbook and logs dives with or without
> signal; there is nothing in the App Store and no TestFlight. To try it, build it onto your own
> phone from source — [CONTRIBUTING.md](CONTRIBUTING.md) says how, with a free Apple Account.

## What it is

A client of *your* OpenDiving server — the one you run, or [opendiving.app](https://opendiving.app)
— with no cloud of its own. The first version asks where the server is, signs in with a code sent
to your email, and shows your logbook: dives with their profile charts, trips and dive sites, in
the units your account uses. Your dive computer's files can be shared to the app from any other
app or picked from Files, and it imports them the way the web does, showing what each file
becomes before anything is written. Or the app downloads them from the computer itself over
Bluetooth: it is built for the Shearwater Perdix 3 and the Suunto Ocean, whose support is
experimental, and every other computer libdc-swift opens is untried. Dives are logged and edited on the phone, on the web's own
form, with or without signal, and reach your server when the phone can; a dive begun on the phone
is a draft the web can finish, and a gear set opens as a checklist to tick at the water's edge.

## Why an app

The [web app](https://github.com/opendiving/opendiving-web) covers logging, trips, gear and
dive-profile charts. The phone is where an app can do what a browser can't:

- **C-cards in your pocket** — your check-in sheet, with every certification card, kept on the
  phone so it opens at the dive shop counter with no signal and after you have signed out, each
  card full-screen at full brightness. This one is in the first version.
- **Bluetooth download from dive computers** — pull dives straight off the wrist, no cables, no
  vendor cloud.
- **Offline-first logging** — dives happen on boats and islands without signal; log now, sync to
  your own server afterwards.

## Stack

SwiftUI on iOS 18 and later, over `OpenDivingKit`, a Swift package holding everything that is not
a view, and [libdc-swift](https://github.com/deepsealabs/libdc-swift), which brings
[libdivecomputer](https://www.libdivecomputer.org/) and the Bluetooth link to dive computers. It
talks to the [opendiving-api](https://github.com/opendiving/opendiving-api) REST API
with the same passwordless sign-in as the web app, by email code.

It needs a server released after v0.6.0 that has dive drafts: the app asks at sign-in for a
session that lasts while the phone is offline, which an older server refuses, and keeps a dive
begun on the phone as a draft on the server, which one without drafts cannot hold.

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

The app links libdc-swift and libdivecomputer, both under the
[GNU LGPL 2.1](LICENSE-LGPL-2.1); [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) names them
and the exact versions built.
