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

`project.yml` imports `.fit`, `.uddf`, `.ssrf`, `.divejson` and `.db` under `app.opendiving.*`, each
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

## What the app starts on its own waits for a route

Every request waits for connectivity, so that a local-network server's first request outlasts the
Local Network prompt; offline, that is a minute's spinner and then a failure. So an outbox flush
or an inbox read the app starts itself does not start while the path reports no route, and a
route appearing starts it. *Sync now* and *Read the files* still try: the diver asked. A create
sent with no route that fails unreachable with none having appeared since waited on the phone,
so it stays unattempted — editable, and a form's draft create still withdrawn when the dive is
logged; one that saw a route come and go may have committed, and counts as sent. Rejected: dropping `waitsForConnectivity`, which fails a request made during
the prompt; a shorter timeout, which still spins and still counts the create as sent.

## A queued write that lands is removed, not logged

The outbox holds what the server has not acknowledged and nothing else: once a write lands the
server holds it, and a second copy on the phone would be a record nobody reconciles. A create is
done only once its `local → server` resolution is on disk, so an item that names the record is
rewritten even if the phone dies between the two writes; the resolution goes a day after landing,
once no queued item or edit draft names the local ref. Rejected: a sync log of sent writes.

## A refused write holds what depends on it; a discard releases it

A 4xx is the server's answer and retrying it changes nothing, so the item fails and every item
naming its record waits behind it — sent first, the dive would lose the site the diver may yet
correct. A discard is the diver's answer: what named the record drops the reference and goes on,
because a dive without its site is still a dive. Rejected: cascading the discard.

## A success this build cannot read is done

A 2xx means the record exists. Retrying it would make a second one the day the key's hold
lapses, so the item leaves the queue with a sentence, and whatever named its record fails with
the same sentence — the uuid can never be learned. A log of a draft that came back unreadable or
gone becomes a plain dive create instead, since it carries the whole dive. Rejected: treating it
as transient.

## Nothing is sent, or cached, before the account loads

A sign-in's answer names no account, so until `GET /user` returns in this process the stores
are the last account's and the token may be another's. Writes made in that window are marked;
the load keeps them or moves them to the loaded account, dropping what names the other's
records. Rejected: flushing on the last-account pointer, which sends one account's queue under
another's token.

## The cache holds what the phone has shown

Pages, dives and drafts are written when a screen loads them, never fetched to fill the cache,
and dive details are bounded to the two hundred most recently opened. It exists so a screen
shows at once and offline, not as a copy of the logbook. Rejected: a sync that pulls every
dive; showing the cache only once a fetch has failed, a minute of spinner offline.

## A computer's record is the account's, and its fingerprint moves only once the archive is kept

The fingerprint of the newest dive downloaded says what one account's logbook holds, so each
account keeps `DiveComputers/<family>_<SERIAL>.json` in its own directory: sign-out leaves it,
`forget` removes it. It is found by family and serial, never by Core Bluetooth's identifier,
which iOS rotates for some computers. It advances only after a completed walk with no empty read,
and only once the inbox has kept the archive for the account the walk began from — or, for a
walk that skipped entries as no dive and delivered none, at its end, there being no archive; a
cancel, a failure, an archive not kept or an app killed at the time-zone question leaves it, and
the import's gates make the re-walked dives links. A record written before the load is removed,
not moved, when the load names another account. Rejected: libdc-swift's `UserDefaults` stores,
keyed by device alone; advancing at import, which needs the inbox to report back across a
sign-out.

## A computer that logs instants keeps two zones, and the diver's wins

A Suunto Nautic reports a dive's start as an instant with no local clock. The record keeps the
zone the watch last reported and the zone the diver named; a start is written in the diver's
where set, else this download's watch's, and only where neither exists does the screen ask,
after the walk and before the archive is written. The offset is the zone's at each dive's own
instant, so a download across a daylight-saving change is right dive by dive. Rejected: `Z`,
which puts UTC on every dive's page; the phone's zone written silently, an offset the source
never carried.

## The Ocean's logbook holds every sport, and a download skips what is not a dive

The Ocean is a sports watch, and the Nautic backend lists its whole logbook, so a run arrives as
a depthless dive. The walk reads each entry's sport from its activity record and skips one whose
id is not a diving sport's (51, 61, 62); the parser's own read rejects a one-digit sport's record
as malformed, so it cannot carry the sport. A skipped entry moves the fingerprint as a dive does,
or every later download reads it again. An entry naming no sport is kept: a dive skipped is never
walked again, an activity kept can be deleted. Rejected: a denylist of known non-dives, which
lets a sport Suunto adds later through as a dive.

## A download's dives carry derived uuids, and waiting downloads are one union

A dive's uuid is version 5 over a fixed namespace, the family, the serial and the fingerprint,
so a re-download is a dive the account already holds and links. One import restores one
full-export archive, so a download arriving beside unimported downloads of the same mark
replaces them with their union — each dive once by uuid, each unnamed member once by digest —
in one inbox save, while the inbox is idle. Rejected: a random uuid, which leaves every dedupe
to the recording gates; an archive per dive.

## The device block has no brand, and its model is spelled as the family's export spells it

The api compares devices by brand, model and serial, and a brand or model both sides carry that
disagree makes them two devices. libdivecomputer says *Shearwater* / *Perdix 3* where Shearwater
Cloud's UDDF says *Shearwater Research, Inc* / *Perdix 3*, and *Suunto* / *Ocean* where the
Suunto app's FIT says *suunto* / *Suunto Ocean*. So no brand, the Petrel family's model is its
product and the Nautic family's is vendor and product, and a Shearwater serial is eight
uppercase hex digits. Rejected: the descriptor's vendor and product, which duplicate the
recordings those exports made.

## The Kit computes its own digests

An archive needs SHA-256 for each member, SHA-1 for the version-5 uuids and CRC-32 for the zip,
and nothing the Kit imports on Linux has them; CryptoKit is Apple-only. They are written in
Swift and tested against their published vectors, so the writer's goldens are the same bytes on
Linux and the simulator. Rejected: a digest seam the app conforms over CryptoKit, which would
make the goldens a fake's output wherever the Kit's tests run.

## What DiveJSON cannot hold rides the recording's extensions, and the server drops it

libdivecomputer reports more than DiveJSON 1.0 holds: each O₂ cell, setpoint, bearing, a stop's
time, a tank's working pressure, the salinity density. The writer puts them under the recording's
`extensions.opendiving`, its doc comment the shape, and nothing under that key on the document, a
dive or a stored file, where the api reads members of its own. The api stores no extensions at
import, so until the format takes these members over they survive on the server only inside the
stored original. Rejected: dropping them; writing vendor records, which the original already holds.

## The import keeps a refused download, and a union never crosses a mark

A download archive is the only copy of its dives until imported, and the import refuses a second
full-export archive as a row, not the request. So the apply discards what it sent except a
download whose own row was refused, which waits to be read again alone; a refused shared file
goes as before, another copy existing. A download unites only with waiting downloads of its own
mark, so the load settles a marked one as it settles any marked file. Rejected: refusing a
shared archive while a download waits.

## The app's tests assert what a screen is given, not the text it draws

A SwiftUI view hosted in the test bundle exposes no accessibility tree — the labels are built
only for an assistive client, and the in-process walk finds none. So a screen's words and rows
come from a Kit value or a static function beside the view (`PendingSummary`,
`PendingScreen.edit(_:)`, `DivesView.list(_:)`), the app test asserts on that over real stores,
and hosting the view checks only that it draws. What UIKit itself draws is the exception — a
text box's placeholder, the navigation title, a picker's current choice — which is how the
record sheets' tests find the web's fields.
Rejected: a UI-test target, a second bundle and a second simulator install for what one value
already settles.

## The phone asks for the extended session, and retries a refresh whose reply was lost

The code sign-in sends `idle_timeout: extended` with no parameter: the Kit's one caller is a
phone that may be offline for weeks. The API spends a refresh token before it answers, and
answers the same cookie presented again inside its reuse grace with the pair it minted, so a
refresh lost on the way back is retried with the same cookie after two seconds, on a twenty-second
timeout, and a 401 to that retry once more. Rejected: retrying at once, which can land before
the server holds the pair.

## Changing server keeps the session; a sign-out is waited for ten seconds

The phone saves every server it is pointed at until it is forgotten, and moving between them
signs nothing out: each keeps its token, its account and its directory, so going back needs no
code and a server that is gone never stands in front of another. Only *Sign out* and *Forget*
end a session, and both wait ten seconds at most, less when the user stops waiting: *Sign out*
then leaves the session as it was, and *Forget* removes everything anyway and says the session
may stay open on the server. Rejected: signing out before the server screen, which leaves a
cancelled change signed out and blocks on a server that cannot answer; signing out of the
server left after switching.

## A typed number takes either decimal separator

The decimal keypad types the region's separator, a comma across much of Europe, and the web reads
a point. `DecimalEntry` and the forms' coordinate boxes take one comma as the point and refuse
text holding both, which is a thousands separator rather than a decimal. They look at the two
characters and never at a `Locale`, so the forms stay under the locale test with `Formatting/`.
Rejected: `NumberFormatter` in the phone's locale, which reads `1.234` as 1234 on a German
phone where the web reads 1.234.

## An edit is kept with the dive as it was loaded

`DiveEditDraft` holds the read the form opened on beside the values, and the queued `PATCH` is
the difference between the two: only what the diver changed, so an edit saved a week later does
not write back the tanks the web changed meanwhile. A field the weather fetch filled is never
sent as null, because the API drops that null. Rejected: sending the whole form, as the web's
edit page does, which undoes whatever the web changed after the phone loaded the dive.

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

## The app depends on libdc-swift, and the Kit on nothing

A Bluetooth protocol stack for forty brands of dive computer is not this project's to write:
libdivecomputer is the library every logbook builds on, and libdc-swift brings its Core Bluetooth
transport and the Suunto Ocean backend upstream has not merged. The app target takes it pinned to
an exact release in `project.yml`, the one place the version lives; the Kit stays dependency-free
and tested on Linux. The app opens a device through the bridge's C entry and walks and parses the
dives itself, since the package's retriever keeps no dive's bytes, its parser drops the zone and
fills defaults, and its own open records devices in `UserDefaults`. Rejected: vendoring upstream
libdivecomputer behind a bridge of our own, which reaches no Ocean.

## libdivecomputer links statically, and the public source meets the LGPL

LGPL-2.1 §6 lets a work linked with the library carry its own terms when whoever receives it can
modify the library and relink. libdc-swift's package links libdivecomputer statically, so §6(a)
is the route: this repository's complete source is public, and the exact pin names the libraries'
source. An app built from source onto one's own phone is not distributed at all.
`THIRD-PARTY-NOTICES.md` and `LICENSE-LGPL-2.1` carry the notice and the text. Rejected: making the
package a dynamic framework, which means maintaining a fork of its layout.

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
