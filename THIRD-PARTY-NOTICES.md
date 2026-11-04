# Third-party notices

The app's own source is licensed under the [Apache License 2.0](LICENSE). The app target
links two libraries under the GNU Lesser General Public License, version 2.1, whose text is in
[LICENSE-LGPL-2.1](LICENSE-LGPL-2.1), one under the MIT licence and one decoder under an
ISC-style licence, both reproduced below, and MapLibre Native, under the BSD 2-Clause licence,
whose notices are in [LICENSE-MapLibre.md](LICENSE-MapLibre.md). Its symbols include icons from Lucide, under the ISC licence, reproduced below too. The
Kit, `OpenDivingKit`, depends on none of them.

## libdc-swift

[deepsealabs/libdc-swift](https://github.com/deepsealabs/libdc-swift), LGPL-2.1, at release
`1.20.0` (commit `5736ed816bb6bfdd2386019bd9ada95b9c923d22`): the Core Bluetooth transport, the
bridge that opens a device, and the Swift package that builds the library below. `project.yml`
pins this exact release.

## libdivecomputer

[libdivecomputer](https://www.libdivecomputer.org/), LGPL-2.1, copyright Jef Driesen and
contributors, compiled from deepsealabs' fork
([deepsealabs/libdivecomputer](https://github.com/deepsealabs/libdivecomputer)) at commit
`1b201bb63b2870a4a0804a92b9ba1b7b003aadea`, the submodule libdc-swift `1.20.0` pins. It talks
to the dive computer, and its parsers read what it sends for libdivejson below.

Both are linked statically, as the package builds them. This repository's complete source and
that exact pin name the libraries' complete source, so whoever receives the app can modify
either library and relink it.

## libdivejson

[divejson/divejson-c](https://github.com/divejson/divejson-c), MIT, at release `0.1.0` (commit
`b51928a01adb8824b8fd35db14ce88bd93ede6eb`): the reader that turns a dive's bytes into a DiveJSON
dive, through the libdivecomputer above, which it compiles against and does not bundle.
`project.yml` pins this exact release.

```
MIT License

Copyright (c) 2026 The DiveJSON Authors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

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

## MapLibre Native

[maplibre/maplibre-native](https://github.com/maplibre/maplibre-native), BSD 2-Clause, copyright
MapLibre contributors and Mapbox, at tag `ios-v7.0.0` (commit
`aae210591243d057e082ea46929a21ad9ea0df6d`), the binary that release `7.0.0` of
[maplibre/maplibre-gl-native-distribution](https://github.com/maplibre/maplibre-gl-native-distribution)
(commit `c2e6e6bd24efa037a8ab13463d8ad047b929eb9f`) carries: it draws a map from a style.
`project.yml` pins this exact release. [LICENSE-MapLibre.md](LICENSE-MapLibre.md) reproduces
`platform/ios/LICENSE.md` at that tag, its own notice and those of the libraries the binary
contains.

## Lucide

[Lucide](https://lucide.dev) icons, from `lucide-static` `1.52.0`, which
`scripts/icons/generate.py` outlines into the app's symbols in `OpenDiving/Sources/Icons.xcassets`.
OpenDiving's own icons there are drawn on Lucide's grid, and some reuse parts of its icons. Its
licence, with the Feather licence it carries for the icons it lists:

```
ISC License

Copyright (c) 2026 Lucide Icons and Contributors

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

---

The following Lucide icons are derived from the Feather project:

airplay, alert-circle, alert-octagon, alert-triangle, aperture, arrow-down-circle, arrow-down-left, arrow-down-right, arrow-down, arrow-left-circle, arrow-left, arrow-right-circle, arrow-right, arrow-up-circle, arrow-up-left, arrow-up-right, arrow-up, at-sign, calendar, cast, check, chevron-down, chevron-left, chevron-right, chevron-up, chevrons-down, chevrons-left, chevrons-right, chevrons-up, circle, clipboard, clock, code, columns, command, compass, corner-down-left, corner-down-right, corner-left-down, corner-left-up, corner-right-down, corner-right-up, corner-up-left, corner-up-right, crosshair, database, divide-circle, divide-square, dollar-sign, download, external-link, feather, frown, hash, headphones, help-circle, info, italic, key, layout, life-buoy, link-2, link, loader, lock, log-in, log-out, maximize, meh, minimize, minimize-2, minus-circle, minus-square, minus, monitor, moon, more-horizontal, more-vertical, move, music, navigation-2, navigation, octagon, pause-circle, percent, plus-circle, plus-square, plus, power, radio, rss, search, server, share, shopping-bag, sidebar, smartphone, smile, square, table-2, tablet, target, terminal, trash-2, trash, triangle, tv, type, upload, x-circle, x-octagon, x-square, x, zoom-in, zoom-out

The MIT License (MIT) (for the icons listed above)

Copyright (c) 2013-present Cole Bemis

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
