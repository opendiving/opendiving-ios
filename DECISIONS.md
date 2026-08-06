# iOS App Decisions & Gotchas

Notes on non-obvious choices made while scaffolding the native iOS client, so the
reasoning survives independently of any particular chat/agent session. Keep this
updated as new gotchas are discovered.

## The refresh-token cookie requires real HTTPS, even for local dev

`opendiving-api`'s sign-in endpoints (`/auth/email/verify`, `/auth/google`,
`/auth/complete` - see the backend's `DECISIONS.md`) set the `refresh_token` cookie
with `secure=True`. Browsers and `URLSession` alike will silently refuse to
store/send a `Secure` cookie over plain HTTP. Point `APIClient.baseURL` at an
HTTPS-reachable instance (a deployed environment, or a local server behind a real
TLS cert/tunnel) - the `POST /auth/refresh` flow will fail silently (not with a
clear error) if this is missed, since `URLSession`'s shared cookie storage just
won't have anything to send.

## Access token lives in the Keychain, not `UserDefaults`

`UserDefaults` is not encrypted at rest. `KeychainHelper` wraps the Security
framework's generic-password APIs for storing/reading/deleting the access token.
Never swap this for `UserDefaults` for anything credential-shaped.

## Two date formats from the API need different decoding

Mirrors the backend/web note: `Dive.start_time` is a full ISO8601 datetime;
`Trip.start_date`/`end_date` are bare `YYYY-MM-DD`. `JSONDecoder`'s built-in
`.iso8601` strategy (set globally on `APIClient`'s decoder) will **not** parse the
bare date fields - when a `Trip` model is added, decode `start_date`/`end_date` as
plain `String` (or a custom date-only `Codable` wrapper) rather than `Date`, or
you'll get decoding failures.

## Never send a dive mixture's `id` back to the API

Same rule as the web frontend: the API replaces all of a dive's mixtures wholesale
on every save (delete-all + re-insert), and the create/update schema forbids
unknown fields. When building the `Dive`/`DiveMixture` create/update payloads,
don't include `id` even if it's present on a `DiveMixture` you fetched from `GET`.

## 422 errors can be an array, not a string

Same shape as the web app's problem: `detail` is either a plain string or an
array of `{type, loc, msg}` validation error objects. `APIErrorDetail` is a custom
`Decodable` enum that tries `String` first, then falls back to
`[ValidationErrorDetail]`, exposing a single `displayMessage` computed property.
Any new error-surfacing code should decode through `APIErrorResponse`/`APIError`
rather than assuming `detail` is always a string.

## `@Observable` requires iOS 17+ / Xcode 15+

`AuthManager` uses the modern `@Observable` macro (not `ObservableObject` +
`@Published`). If this project ever needs to support iOS versions older than 17,
`AuthManager` (and any future `@Observable` view models) will need to be rewritten
using `ObservableObject`/`@Published`/`@StateObject` instead - decide the minimum
supported iOS version early, since this affects every view model, not just this one.

## Repo layout is a placeholder

This folder currently holds flat Swift files organized into `Models/`,
`Networking/`, `Auth/`, `Views/Auth/` purely as filesystem folders - there is no
`.xcodeproj` yet. When creating the actual Xcode project, add these files via
"Add Files to..." and let Xcode generate matching groups; there's no requirement
that the on-disk layout continue to mirror the Xcode group structure going
forward, but keeping them in sync is easier to navigate.
