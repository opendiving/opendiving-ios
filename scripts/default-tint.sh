#!/bin/sh
# Fails where the app leaves a control in the default tint, which iOS brightens when Increase
# Contrast is on: `Color.accentColor`, a bare bordered button style, and a prominent button, inline
# or pushed picker or progress bar with no `.tint(` within three lines of it. Also a `Toggle` with no
# `.tint(` before the next one, which draws the system's green switch; one in a menu, a checkmark,
# is left alone. DECISIONS.md, "The accent is always given, never left to the default tint", has
# why; it catches the common cases, not every one.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd -P)

program='
  function report(i, why) {
    printf "%s:%d: %s\n", substr(file, length(root) + 1), i, why
    failed = 1
  }
  function check(    i, j, tinted, own, menu) {
    own = file ~ /View\+BrandBorderedButton\.swift$/
    menu = file ~ /Menu\.swift$/
    for (i = 1; i <= n; i++) {
      if (lines[i] ~ /accentColor/)
        report(i, "Color.accentColor is the default tint; use Color.accentText")
      if (lines[i] ~ /buttonStyle\(\.bordered\)/ && !own)
        report(i, "a bordered button takes brandBorderedButton()")
      if (lines[i] ~ /\.(borderedProminent|glassProminent)\)|pickerStyle\(\.(inline|navigationLink)\)|ProgressView\(value/) {
        tinted = 0
        for (j = i - 3; j <= i + 3; j++)
          if (j >= 1 && j <= n && lines[j] ~ /\.tint\(/) tinted = 1
        if (!tinted) report(i, "give it a .tint(...), or the default tint draws it")
      }
      if (lines[i] ~ /(^|[^A-Za-z0-9_.])Toggle\(/ && !menu) {
        tinted = 0
        for (j = i; j <= i + 12 && j <= n; j++) {
          if (j > i && lines[j] ~ /(^|[^A-Za-z0-9_.])Toggle\(/) break
          if (lines[j] ~ /\.tint\(|toggleStyle\(\.button\)/) tinted = 1
        }
        if (!tinted) report(i, "a switch takes .tint(.brandTeal), or it draws the system green")
      }
    }
  }
  FNR == 1 { if (n) check(); n = 0; file = FILENAME }
  { lines[++n] = $0 }
  END { if (n) check(); exit failed }
'

find "$root/OpenDiving/Sources" -name '*.swift' -exec awk -v root="$root/" "$program" {} + || {
  echo "default-tint.sh: the accent has to be given; see AGENTS.md" >&2
  exit 1
}
