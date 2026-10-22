# Contributing to OpenDiving iOS

Thanks for wanting to help. This is the iPhone app; the server it talks to is
[opendiving-api](https://github.com/opendiving/opendiving-api), and if you want something to sign
in to while you work, [opendiving/opendiving](https://github.com/opendiving/opendiving) has the
self-hosting bundle — a local instance is a `docker compose up` away.

## What you need

- A Mac with **Xcode 26.3 or later** and an iOS simulator runtime (Xcode → Settings → Components).
  CI builds with 26.3 and the maintainers with 27, so the project has to build under both.
- **[XcodeGen](https://github.com/yonaskolb/XcodeGen)**, which writes the Xcode project:
  `brew install xcodegen`.

Nothing else: no CocoaPods, no third-party packages, no SwiftLint. Formatting is the toolchain's own
`swift format`.

## Generating the project

`OpenDiving.xcodeproj` is generated from `project.yml` and is not in git. Generate it after cloning,
after pulling a change to `project.yml`, and after editing it yourself:

```bash
xcodegen generate
```

Then open `OpenDiving.xcodeproj` in Xcode, or use the commands below. Adding a Swift file needs no
regenerate — the app's and the tests' folders are synchronized folders, so a file is in its target
by existing.

## Building and testing

This section is the test suite. Run all of it before you open a pull request; CI runs the same
commands.

Build the app for the simulator:

```bash
xcodebuild build -project OpenDiving.xcodeproj -scheme OpenDiving \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath .build
```

Test the app bundle and the Kit together, on a simulator of this checkout's own:

```bash
xcodebuild test -project OpenDiving.xcodeproj -scheme OpenDiving \
  -destination "id=$(scripts/simulator.sh)" -derivedDataPath .build
```

`scripts/simulator.sh` creates an iPhone simulator named after the checkout's path on first use and
prints its UDID every time after. Never point the test command at a shared, named simulator: two
test runs installing the app on the same device kill each other's test host, and two checkouts of
this repository can easily be testing at once.

Test the Kit alone — quicker, and what CI runs on Linux:

```bash
swift test --package-path Packages/OpenDivingKit
```

Check the formatting, and fix it:

```bash
swift format lint --strict --recursive .
swift format --in-place --recursive .
```

Warnings are errors in both the app and the Kit, so a build that prints one has failed.

## Running on your iPhone

A free Apple Account is enough to put the app on your own phone; no developer program membership.

1. In Xcode → Settings → Apple Accounts, sign in. Xcode lists your account's **Personal Team** and
   its Team ID.
2. Create `Signing.local.xcconfig` at the repository root with your Team ID:

   ```
   DEVELOPMENT_TEAM = ABCDE12345
   ```

   The file is gitignored and nothing tracked ever carries a Team ID. Bundle identifiers are unique
   across teams, so once `app.opendiving.ios` is registered to someone else's team, yours is
   refused it: add a line of your own to the same file, and nothing tracked changes.

   ```
   PRODUCT_BUNDLE_IDENTIFIER = com.example.opendiving
   ```

3. Connect the phone, trust the Mac on it, and turn on Developer Mode (Settings → Privacy & Security
   → Developer Mode). The switch appears only once Xcode has started pairing, which opening Xcode's
   device window with the phone connected does.

Then build for the phone and install it, with the phone's UDID — the `id` that
`xcodebuild -showdestinations -project OpenDiving.xcodeproj -scheme OpenDiving` lists for it:

```bash
xcodebuild build -project OpenDiving.xcodeproj -scheme OpenDiving \
  -destination "id=<UDID>" -derivedDataPath .build -allowProvisioningUpdates
xcrun devicectl device install app --device <UDID> \
  .build/Build/Products/Debug-iphoneos/OpenDiving.app
```

Choosing the phone as the run destination in Xcode and pressing Run does the same. The first launch
stops at *Untrusted Developer*: Settings → General → VPN & Device Management, trust your developer
profile, and launch again.

**A Personal Team's provisioning profile expires after seven days**, and then the app no longer
launches. Rebuild and reinstall with the same two commands; installing over the existing app keeps
its data, while deleting it first does not.

## Pull requests

- Branch from `main`, and keep a pull request to one change.
- Title it as a conventional commit — `<type>[(scope)][!]: <description>`, e.g.
  `feat: the dive list and the dive detail`. Types: `feat`, `fix`, `refactor`, `docs`, `test`,
  `chore`, `perf`, `ci`, `build`, `revert`. A CI check enforces this, and re-runs when you edit the
  title, so a rejected PR needs no new commit. PRs are squash-merged, so the title becomes the
  commit subject on `main` — commits within your branch can say whatever is useful while working.
- Say in the description what you changed and why, and add a screenshot for anything visual.
- A change that needs the API to change starts on the API side: open the
  [opendiving-api](https://github.com/opendiving/opendiving-api) PR first and link the two.
- Hit something non-obvious? It belongs in `DECISIONS.md`, in the same PR — under the bar
  `AGENTS.md` sets.

## Reporting bugs and security issues

Bugs and ideas go in this repository's [issues](https://github.com/opendiving/opendiving-ios/issues).
A vulnerability does not — see [SECURITY.md](SECURITY.md) for the private channel.

## License

By contributing you agree that your contribution is licensed under the
[Apache License 2.0](LICENSE), like the rest of this repository.
