# Fixtures

Recorded API responses the Kit's tests decode, one JSON file per case. The whole
directory is copied into the test bundle (`resources: [.copy("Fixtures")]` in
`Package.swift`), so adding a fixture is creating a file here; read it through
`Bundle.module.url(forResource:withExtension:subdirectory: "Fixtures")`.
