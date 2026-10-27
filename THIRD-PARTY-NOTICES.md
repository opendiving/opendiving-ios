# Third-party notices

The app's own source is licensed under the [Apache License 2.0](LICENSE). The app target
links two libraries under the GNU Lesser General Public License, version 2.1, whose text is in
[LICENSE-LGPL-2.1](LICENSE-LGPL-2.1), and one decoder under an ISC-style licence, reproduced
below. The Kit, `OpenDivingKit`, depends on none of them.

## libdc-swift

[deepsealabs/libdc-swift](https://github.com/deepsealabs/libdc-swift), LGPL-2.1, at release
`1.18.0` (commit `dc1d5e2394646aee58d70c8fee1bddfb5c2a7bc4`): the Core Bluetooth transport, the
bridge that opens a device, and the Swift package that builds the library below. `project.yml`
pins this exact release.

## libdivecomputer

[libdivecomputer](https://www.libdivecomputer.org/), LGPL-2.1, copyright Jef Driesen and
contributors, compiled from deepsealabs' fork
([deepsealabs/libdivecomputer](https://github.com/deepsealabs/libdivecomputer)) at commit
`1f7c4ff1cab0368a1ee1a6edbd61e30667d339c0`, the submodule libdc-swift `1.18.0` pins. It talks
to the dive computer and parses what it sends.

Both are linked statically, as the package builds them. This repository's complete source and
that exact pin name the libraries' complete source, so whoever receives the app can modify
either library and relink it.

## heatshrink

The fork vendors the heatshrink decoder under `src/heatshrink/`, which the package compiles:

```
Copyright (c) 2013-2015, Scott Vokes <vokes.s@gmail.com>
All rights reserved.

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
```
