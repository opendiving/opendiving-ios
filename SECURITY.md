# Security Policy

This repository is the iPhone app: a client of an OpenDiving server, holding on the phone what it
needs to stay signed in, to show your check-in sheet and the logbook pages it has shown without
signal, to keep the drafts, the dives waiting to sync and the files waiting to be read until the
server has them, and to remember the dive computers it has downloaded from. A flaw in this code affects everyone who runs the app, and we would much
rather hear about one privately than read about it in a public issue.

**No running instance is a target for testing, and the one this project operates,
[opendiving.app](https://opendiving.app), is not an exception.** It holds real divers' data. Point
the app at a server you run yourself — the
[self-hosting bundle](https://github.com/opendiving/opendiving) is a `docker compose up` away — and
test that as hard as you like; a finding in the code is the same finding wherever it was found.

This project is run by a single maintainer in their spare time. There is no bug bounty and no money
behind it — what we can offer is a reply from a person, a fix on `main`, and credit if you want it.

## Reporting a vulnerability

**Use GitHub's private vulnerability reporting:**
**[Report a vulnerability](https://github.com/opendiving/opendiving-ios/security/advisories/new)**,
or the *Report a vulnerability* button on this repository's **Security** tab. It opens an advisory
only the maintainers can see. Please don't open a public issue or pull request for something
exploitable; the fix and the disclosure should arrive together.

No GitHub account, or the form isn't working for you? Email **security@opendiving.app**. It reaches
the maintainers and nobody else.

What helps most:

- **What an attacker gets** — a session token, another account's data, the cached check-in sheet,
  logbook pages, drafts, dives waiting to sync or the dive computers remembered — their serials —
  off a phone they hold.
- **How to reproduce it** — the steps in the app, and the server and request involved.
- **Which version** — the commit you built from, and the iOS version on the phone.

## Scope

In scope is anything in this repository: how the app stores credentials, the cached sheet, the
copies of the logbook, the drafts, the queue of writes waiting to sync, the files waiting to be
read and the dive computers it remembers on the phone, how it talks to a server — which origins
it trusts, what it sends where — and how it handles what a server sends back. So is how it handles
what a dive computer sends over Bluetooth, which libdivecomputer parses inside the app through
[libdc-swift](https://github.com/deepsealabs/libdc-swift); a flaw in either library belongs
upstream, and if you are not sure which side it is on, send it here.

Out of scope here is the server itself. Authentication, authorization and stored data are enforced
by [opendiving-api](https://github.com/opendiving/opendiving-api), and a flaw on that side belongs
in [its SECURITY.md](https://github.com/opendiving/opendiving-api/blob/main/SECURITY.md). Same
maintainer either way: if you are not sure which side it is on, send it here and it will be routed.

## What happens next

A person reads it and replies. From there we reproduce it, agree with you on how bad it is, and fix
it on `main`. The app is not distributed through the App Store — everyone builds it from source —
so the supported version is the newest commit, and the fix reaches you when you rebuild. We publish
an advisory once the fix is on `main`, crediting you by name unless you'd rather we didn't.
