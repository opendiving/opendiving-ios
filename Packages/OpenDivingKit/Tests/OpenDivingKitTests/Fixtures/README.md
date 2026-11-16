# Fixtures

Recorded API responses the Kit's tests decode, one JSON file per case. The whole
directory is copied into the test bundle (`resources: [.copy("Fixtures")]` in
`Package.swift`), so adding a fixture is creating a file here; read it through
`Bundle.module.url(forResource:withExtension:subdirectory: "Fixtures")`.

A fixture captured from a running instance has every name, address, phone and number that
belongs to a person replaced before it is committed — this repository is public. The cases a
real account rarely holds (two recordings on one dive, every profile channel, the four
`start_time` spellings) are written by hand from the API's schemas.

Every JSON file here has an entry in `Packages/OpenDivingKit/api-bodies.json`, naming the
operation whose response or request body it is (every one, where a test serves it for several), or
the component schema for an error body or a part of one. CI holds each file to that schema in the
API's document, so a new fixture gets its entry in the same change, and a value it holds on purpose
that the API does not send is exempted there, at its place, with the reason. `CONTRIBUTING.md`
has the command.
