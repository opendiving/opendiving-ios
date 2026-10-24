# Decisions

Choices the code cannot explain by itself. Each says what was chosen, what was rejected and why;
`AGENTS.md` sets the bar for adding one.

## Credentials live in the Keychain, never `UserDefaults`

Anything credential-shaped the app keeps across launches is a Keychain item, keyed by server
origin. `UserDefaults` is a plist on disk, unencrypted at rest and included in backups. The refresh
token does not live in `HTTPCookieStorage` either, although the API sends it as a cookie: the app
reads it off `Set-Cookie`, stores it itself and sends it back on the routes that read it and no other, so
that it can be keyed, wiped and protected per server. The Kit declares the store as a protocol and
the app target conforms it over the Keychain, which keeps `Security` out of the Kit.

## The first launch of an install clears the Keychain

iOS keeps an app's Keychain items when the app is deleted, while its container — the defaults and
Application Support — goes with it, so a reinstall would inherit the previous install's session.
The first launch removes every refresh-token item before the session is built, then sets a flag
in `UserDefaults`; the flag is what tells a fresh install from an install over the existing app,
which keeps its container and its session.
Rejected: the flag in the Keychain, which survives the delete it is meant to detect.

## An error's `detail` is a string, except on a validation 422

FastAPI answers `{"detail": "…"}` for every error but request validation, where `detail` is an
array of `{type, loc, msg, input}` and `loc` mixes strings and integers (`["body", "mixtures", 0,
"o2"]`). Decode `detail` as either shape and show one message; typing `loc` as `[String]` fails on
exactly the nested fields a 422 is most likely about.

## A dive's `start_time` has four spellings, and no date strategy reads them all

The API writes an offset-aware value with or without a fraction (`…T10:04:00.5+02:00`), `Z` for
UTC, a naive value for a dive whose zone was never recorded (`…T11:49:00`), and a bare date for a
dive that carries only its day (`2002-06-18`). `JSONDecoder`'s `.iso8601` rejects three of the four,
and any `Date` loses the difference between them. `DiveTimestamp` keeps three states and
`CalendarDate` is every date-only field — trip parts, `certified_on`, `expires_on` — so that no day
passes through a UTC-midnight `Date`, which a zone west of UTC prints as the day before.

## Every figure prints as the web prints it, not as the phone's locale would

The Kit's formatters are ports of the web's and agree with it to the character: `UnitFormat`,
`DateText` and the profile readouts write `30.52 m`, `Apr 4, 2021, 10:04` and `21.6°C` in
every region, because the web pins `en-US` and the two are compared side by side. So nothing
under `Formatting/` reads a `Locale`, and a test fails if anything does. Numbers go
through `NumberText`, which reproduces JavaScript's `String(n)`, `toFixed` and `Math.round`:
Swift's `"\(28.0)"`, a tie-to-even `%.0f` and `rounded()` each print a plausible figure that
disagrees with the web. Rejected: `FormatStyle` and `MeasurementFormatter`, which localise
correctly and would contradict the web on the same account. Change one side, change both.

## A request body is a type of its own, never a `*Read` sent back

Every write schema the API has forbids unknown fields, and its read schemas carry members no write
takes — a mixture's `id`, the API's internal integer, among them — so a `*Read` re-sent is a 422.
Each body is its own type under `Requests/`, holding the schema's members and no others, and its
fixture is a body the schema accepts that the type must encode to exactly. Rejected: one model
both ways with the read-only members made optional, which sends them the moment they are set.

## A local record's ref never reaches the wire

A record created offline is named `RecordRef.local` until its create lands. The encoder a request
body is sent with throws on one rather than writing it, because the API would refuse the uuid
and the queue owes a rewrite to the server's first. The encoder that keeps a body on the phone
writes it as `local:<uuid>`, so a queued body reads back as queued.

## What is an account's lives in its own directory inside the server's

A sign-in to the same server can be another account, so a queue or a draft kept by origin alone
would be sent under the wrong account's token. Each account has `Servers/<slug>/Accounts/<uuid>/`,
and the server's directory holds a pointer to the account `loadAccount()` last read — written
then, because a sign-in's answer names no account — which a sign-out leaves, so a signed-out
phone still knows whose stores and form settings to show. `forget` removes the lot.

## Shared files are imported types, copied in

`project.yml` imports `.fit`, `.uddf`, `.ssrf` and `.divejson` under `app.opendiving.*`, each
conforming to `public.data`, and lists `public.json`, `public.xml` and `public.zip-archive` beside
them, every entry a viewer ranked `Alternate`: the project owns none of these formats, and
exporting one would outrank its owner's declaration. `LSSupportsOpeningDocumentsInPlace` is false,
so iOS copies the file into `Documents/Inbox` and the app moves that copy into the account's
inbox. SwiftUI's `onOpenURL` is what delivers it — a document as well as a link. Rejected: a share extension, which needs a second bundle id.

## The inbox reads on its own only when no read covers it

Every preview sends every waiting file and spends one of the hourly imports the apply also
spends, so a file arriving into a covered inbox marks the read stale and waits for the diver's
*Read the files again*. A refusal, a 429 and a 5xx are kept like a preview, so the app never
retries what the server answered.

## The phone asks for the extended session, and retries a refresh whose reply was lost

The code sign-in sends `idle_timeout: extended` with no parameter: the Kit's one caller is a
phone that may be offline for weeks. The API spends a refresh token before it answers, and
answers the same cookie presented again inside its reuse grace with the pair it minted, so a
refresh lost on the way back is retried with the same cookie after two seconds, on a twenty-second
timeout, and a 401 to that retry once more. Rejected: retrying at once, which can land before
the server holds the pair.

## The Xcode project is generated by XcodeGen

`project.yml` is the source of truth and `OpenDiving.xcodeproj` is gitignored. A tracked
`.pbxproj` needs a GUI or a hand-rolled plist to create and is a merge hazard on every later change;
generated, it cannot drift from the file people review. Sources are synchronized folders, so adding
a file never touches the project. Rejected: a committed `.pbxproj`; Tuist, a larger dependency for
the same result.

## The Kit's tools version is 6.2

`swift-tools-version: 6.2` is the floor for `defaultIsolation` and `treatAllWarnings(as:)`, and
every supported toolchain accepts it — CI's macOS image builds with an older Xcode than the
maintainers use, and a manifest at the newest toolchain's version is refused by the older one.
Raise it only when the oldest Xcode in use (CI's included) accepts the new number.

## The Kit builds on Linux

CI tests the Kit on Linux, so it imports neither UIKit, SwiftUI nor Security — not even behind
`#if canImport`, which would be a second code path no test runs. What only the device has is a Kit
protocol with its one conformance in the app target, and the Kit's tests use a fake. Rejected: a
second package for the Apple half, a manifest and a target for each such type.

## CI builds the app on macos-15 with Xcode 26.3

`app-macos` runs on `macos-15` with `DEVELOPER_DIR` naming Xcode 26.3, which carries the iOS 26.2
SDK. `macos-26` is not offered to this organization, the image's default Xcode (16.4) predates
the Kit's tools version, and `macos-latest` names an image that moves without a change here. So
nothing in the project or the sources may need a newer SDK, unless behind an availability check. Move the job to a newer label, and its Xcode with it, once one is offered.

## CI pins the Linux toolchain to a patch release

The Linux job runs in `swift:6.4.0-noble`, not the floating `swift:6.4-noble`, because it is also
where `swift format lint` runs, and a formatter a patch release ahead of the one in the
maintainers' Xcode can disagree with it about a file. Move the pin with the maintainers' Xcode.
The container, rather than the runner image's own Swift, is what keeps the toolchain fixed while
`ubuntu-latest` moves.
