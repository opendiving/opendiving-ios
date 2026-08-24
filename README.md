# OpenDiving iOS

**The iOS companion app for [OpenDiving](https://github.com/opendiving/opendiving-web)
— a self-hosted, open-source dive log.**

> ⚠️ **Early stage.** The SwiftUI app skeleton (auth, networking, first views) is in
> progress; there is nothing to install yet. Watch the repo or dive into the open
> issues if you'd like to help shape it.

## Why an app

The [web app](https://github.com/opendiving/opendiving-web) covers logging, trips,
gear, and dive-profile charts. The phone is where the app can do what a browser
can't:

- **Bluetooth download from dive computers** — pull dives straight off the wrist,
  no cables, no vendor cloud.
- **Offline-first logging** — dives happen on boats and islands without signal; log
  now, sync to your own server later.
- **C-cards in your pocket** — show certifications at the dive shop from the
  Certifications store.

## Stack

SwiftUI, talking to the [opendiving-api](https://github.com/opendiving/opendiving-api)
REST API with the same passwordless (magic link / Google) authentication as the web
app.

## Related repositories

| | |
|---|---|
| [opendiving-api](https://github.com/opendiving/opendiving-api) | FastAPI backend — start here to self-host |
| [opendiving-web](https://github.com/opendiving/opendiving-web) | Next.js frontend — features and screenshots |

## License

Licensed under the [Apache License 2.0](LICENSE) — permissive on purpose, so
third-party clients for the OpenDiving API are welcome. The server stays
AGPL-licensed; the data stays yours.
