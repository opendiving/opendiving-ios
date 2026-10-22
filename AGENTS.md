# opendiving-ios

SwiftUI app for iPhone, iOS 18 and later, plus `OpenDivingKit`, the local Swift package it is built
on (the Kit). It is a client of an OpenDiving server — [opendiving-api](https://github.com/opendiving/opendiving-api)'s
REST API, whoever runs it — and has no backend of its own.

`DECISIONS.md` in this repo holds the reasoning behind most of what follows — grep it for what you
are about to touch and read the matching section. Append to it only when the code cannot carry the
reason; a one-line comment at the site is the better home for most of them. An entry is under 150
words, present tense: what was chosen, what was rejected, why. No history, no symptom narrative, no
verification story — git holds the previous state.

The commands — generate, build, test, format, install on a phone — are in `CONTRIBUTING.md`, and
its *Building and testing* section is this repo's test suite: run all of it before you hand a
change over.

## Layout

- `project.yml` is the Xcode project. `OpenDiving.xcodeproj` is generated from it by
  `xcodegen generate` and is never tracked — change the project by editing `project.yml`, never in
  Xcode's project editor, where the edit is lost at the next generate.
- `OpenDiving/Sources` is the app target and `OpenDivingTests` its test bundle. Both are
  synchronized folders: a new Swift file is part of the target by existing, with no project edit
  and no regenerate.
- `Packages/OpenDivingKit` is the Kit: `Sources/OpenDivingKit` and `Tests/OpenDivingKitTests`, by
  SwiftPM's convention. Test fixtures go in `Tests/OpenDivingKitTests/Fixtures`, which the
  manifest already copies whole.

## What goes where

- **Everything that is not a view lives in the Kit**: models and their decoding, the API client,
  authentication, the session, unit and date formatting, caches, and every view model that needs
  no UIKit. The Kit's tests run on Linux in CI, which is what makes this a rule rather than a
  preference.
- **The Kit imports neither UIKit, SwiftUI nor Security.** Where the Kit needs something only the
  device has — the Keychain, the screen's brightness — it declares a protocol and the app target
  conforms to it (`ScreenBrightness`, `WindowSceneBrightness`). The Kit's tests use a fake.
- **The app target holds views, app-lifecycle glue and those conformances**, nothing else.
- **A view takes plain values.** The shared views in `OpenDiving/Sources/Shared` — the dive card,
  the hero, the map, the people row, the species card, the empty-or-error state — draw a Kit value
  type (`DiveCardContent`, `HeroContent`, …) and know nothing of the model it came from. The
  mapping from a model to that value is a Kit function with tests.
- **A view two screens need is shared**, in `Shared/`, never a second copy in the second screen's
  folder.

## Adding a screen

Create the view in its feature's folder under `OpenDiving/Sources` (`Dives/`, `Trips/`, …) and its
view model in the Kit, then reach it from the screen that shows it. A placeholder screen keeps its
type name and its initializer when it is filled in, because other screens already construct it by
that name. Give every view a `#Preview`.

## Code style — Swift

- Swift 6 language mode everywhere, and warnings are errors (`project.yml` and `Package.swift`
  both say so). The app target's default isolation is `MainActor`; the Kit's is `nonisolated`, so
  mark what must run on the main actor there.
- `swift format`, the toolchain's own, with its default configuration: two-space indent, 100
  columns. `CONTRIBUTING.md` has the command; CI fails a tree it would change.
- `UpperCamelCase` types, `lowerCamelCase` everything else, one primary type per file named after
  it.
- Comments say why, not what. A doc comment (`///`) on a public Kit declaration whose name does not
  already say it all.
- Swift Testing (`import Testing`, `@Test`, `#expect`) for new tests, in the Kit and the app bundle
  alike.

## Consuming the API

The API returns resource schemas directly — no envelope — and signals failure with the status
code. Errors carry FastAPI's `{ "detail": ... }`, a string except for a validation 422, where it is
an array of objects. Paginated endpoints return
`{ data, total_count, has_more, page, items_per_page }`. The full contract is in
[opendiving-api's AGENTS.md](https://github.com/opendiving/opendiving-api/blob/main/AGENTS.md).

## Commit signing

Never switch commit signing off on the git command line. Where signing is on in the git
configuration you are running under, overriding it inline leaves a PR whose every commit reads
*Unverified*; where it is not configured, commit normally and do not set it up — PRs are
squash-merged, and GitHub signs the commit that lands on `main`. If signing is on and genuinely
fails, report the error instead of routing around it.
