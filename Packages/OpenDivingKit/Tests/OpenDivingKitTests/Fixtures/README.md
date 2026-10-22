# Fixtures

Recorded API responses the Kit's tests decode, one JSON file per case. The whole
directory is copied into the test bundle (`resources: [.copy("Fixtures")]` in
`Package.swift`), so adding a fixture is creating a file here; read it through
`Bundle.module.url(forResource:withExtension:subdirectory: "Fixtures")`.

A fixture captured from a running instance has every name, address, phone and number that
belongs to a person replaced before it is committed — this repository is public. The cases a
real account rarely holds (two recordings on one dive, every profile channel, the four
`start_time` spellings) are written by hand from the API's schemas.
