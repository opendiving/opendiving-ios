#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = ["picosvg==0.23.0"]
# ///
"""Writes the app's own symbols: OpenDiving/Sources/Icons.xcassets and the Kit's `Icon`.

The Lucide icons named in icons.json come from the pinned `lucide-static` release, the one
opendiving-web's `lucide-react` is on; custom/ holds OpenDiving's own, drawn on Lucide's
24-unit grid with its 2-unit stroke. Each becomes a custom SF Symbol, its strokes outlined,
since a symbol template draws fills only. Both outputs are committed and wholly generated:
edit icons.json or custom/ and run this again.
"""

import base64
import hashlib
import io
import json
import re
import shutil
import tarfile
import urllib.request
from pathlib import Path

from picosvg.svg import SVG
from picosvg.svg_types import SVGPath
from picosvg.svg_transform import Affine2D

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
CATALOG = ROOT / "OpenDiving/Sources/Icons.xcassets"
ENUM = ROOT / "Packages/OpenDivingKit/Sources/OpenDivingKit/Presentation/Icon.swift"

# The template's medium scale is drawn at 100 pt, where a cap height is 70.46 units. Lucide's
# 24-unit box becomes 108 units, so a glyph spanning its 2–22 keylines stands 90 tall, as an
# SF Symbol's does, centred on the cap height as SF Symbols are.
SCALE = 4.5
BASELINE = 1126.0
CAP_HEIGHT = 70.46
LEFT = 1400.0


def lucide_svgs(version: str, integrity: str, names: list[str]) -> dict[str, bytes]:
    url = f"https://registry.npmjs.org/lucide-static/-/lucide-static-{version}.tgz"
    with urllib.request.urlopen(url) as response:
        archive = response.read()
    algorithm, expected = integrity.split("-", 1)
    digest = base64.b64encode(hashlib.new(algorithm, archive).digest()).decode()
    if digest != expected:
        raise SystemExit(f"lucide-static {version} does not match its integrity hash")
    svgs = {}
    with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
        for name in names:
            member = tar.extractfile(f"package/icons/{name}.svg")
            if member is None:
                raise SystemExit(f"lucide-static {version} has no icon {name}")
            svgs[name] = member.read()
    return svgs


def outlined_paths(svg: bytes, scale: float, stroke: float) -> list[str]:
    # Lucide's files open with a licence comment, which the parser takes for the root.
    text = re.sub(rb"<!--.*?-->", b"", svg, flags=re.S).decode()
    text = text.replace('stroke-width="2"', f'stroke-width="{stroke:g}"', 1)
    picture = SVG.fromstring(text).topicosvg()
    to_template = Affine2D(scale, 0, 0, scale, 0, -12 * scale - CAP_HEIGHT / 2)
    return [
        shape.as_path().apply_transform(to_template).round_floats(2).d
        for shape in picture.shapes()
    ]


def anchored(part: list[str], whole: list[str]) -> list[str]:
    # A symbol is drawn to its own shapes' bounds, so a part alone would be scaled to fill the
    # frame. A speck at two corners of the whole icon's bounds, too small to draw, gives every part
    # the whole's bounds, and the parts land on each other where the whole has them.
    boxes = [SVGPath(d=d).bounding_box() for d in whole]
    left = min(box.x for box in boxes)
    top = min(box.y for box in boxes)
    right = max(box.x + box.w for box in boxes)
    bottom = max(box.y + box.h for box in boxes)
    speck = 0.01
    return part + [
        f"M{left:g} {top:g}h{speck}v{speck}h-{speck}Z",
        f"M{right - speck:g} {bottom - speck:g}h{speck}v{speck}h-{speck}Z",
    ]


def template(paths: list[str], scale: float) -> str:
    glyphs = "\n".join(
        f'      <path class="monochrome-0 multicolor-0:tintColor hierarchical-0:primary" d="{d}"/>'
        for d in paths
    )
    guide = 'style="fill:none;stroke:#27AAE1;opacity:1;stroke-width:0.5;"'
    lines = []
    for size, baseline in (("S", 696.0), ("M", BASELINE), ("L", 1556.0)):
        for line, y in (("Baseline", baseline), ("Capline", baseline - CAP_HEIGHT)):
            lines.append(
                f'    <line id="{line}-{size}" {guide} x1="263" x2="3036" y1="{y:g}" y2="{y:g}"/>'
            )
    for side, x in (("left", LEFT), ("right", LEFT + 24 * scale)):
        lines.append(
            f'    <line id="{side}-margin-Regular-M" {guide} x1="{x:g}" x2="{x:g}" '
            f'y1="{BASELINE - 100:g}" y2="{BASELINE + 30:g}"/>'
        )
    guides = "\n".join(lines)
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
<svg version="1.1" xmlns="http://www.w3.org/2000/svg" width="3300" height="2200">
  <g id="Notes">
    <rect height="2200" id="artboard" style="fill:white;opacity:1" width="3300" x="0" y="0"/>
    <text id="template-version" style="stroke:none;fill:black;font-family:sans-serif;font-size:13;" transform="matrix(1 0 0 1 3036 1933)">Template v.3.0</text>
  </g>
  <g id="Guides">
{guides}
  </g>
  <g id="Symbols">
    <g id="Regular-M" transform="matrix(1 0 0 1 {LEFT:g} {BASELINE:g})">
{glyphs}
    </g>
  </g>
</svg>
"""


def case_name(icon: str) -> str:
    head, *rest = icon.split("-")
    return head + "".join(word.capitalize() for word in rest)


def enum_source(icons: list[str]) -> str:
    cases = "\n".join(
        f"  case {case}" if case == icon else f'  case {case} = "{icon}"'
        for icon in icons
        for case in [case_name(icon)]
    )
    return f"""// Generated by scripts/icons/generate.py from scripts/icons; do not edit.

/// One of the app's own symbols — Lucide's, and OpenDiving's drawn to match — named as the
/// asset catalog names it. System chrome stays on SF Symbols.
public enum Icon: String, CaseIterable, Hashable, Sendable {{
{cases}
}}
"""


def main() -> None:
    manifest = json.loads((HERE / "icons.json").read_text())
    lucide = manifest["lucide"]
    sources = lucide_svgs(lucide["version"], lucide["integrity"], lucide["icons"])
    for path in sorted((HERE / "custom").glob("*.svg")):
        if path.stem in sources:
            raise SystemExit(f"custom/{path.name} shadows the Lucide icon of that name")
        sources[path.stem] = path.read_bytes()

    if CATALOG.exists():
        shutil.rmtree(CATALOG)
    CATALOG.mkdir(parents=True)
    info = {"info": {"author": "xcode", "version": 1}}
    (CATALOG / "Contents.json").write_text(json.dumps(info, indent=2) + "\n")
    # A record's icon drawn large in a card's water is drawn again, larger in its frame and with
    # a heavier stroke, so it holds its own at that size.
    tab = manifest["tab"]
    symbols = {name: (svg, SCALE, 2.0, None) for name, svg in sources.items()}
    for name in tab["icons"]:
        symbols[f"tab-{name}"] = (sources[name], SCALE * tab["scale"], tab["stroke"], None)
    # An icon drawn in two colours is drawn as its parts, one symbol each, which laid over each
    # other make the whole: a part is the icon's shapes at those places, in its file's order.
    for name, parts in manifest.get("parts", {}).items():
        for part, shapes in parts.items():
            symbols[f"{name}-{part}"] = (sources[name], SCALE, 2.0, shapes)
    for name, (svg, scale, stroke, shapes) in sorted(symbols.items()):
        symbolset = CATALOG / f"{name}.symbolset"
        symbolset.mkdir()
        paths = outlined_paths(svg, scale, stroke)
        if shapes is not None:
            paths = anchored([paths[index] for index in shapes], paths)
        (symbolset / f"{name}.svg").write_text(template(paths, scale))
        contents = {"info": info["info"], "symbols": [{"filename": f"{name}.svg", "idiom": "universal"}]}
        (symbolset / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")

    ENUM.write_text(enum_source(sorted(symbols)))


if __name__ == "__main__":
    main()
