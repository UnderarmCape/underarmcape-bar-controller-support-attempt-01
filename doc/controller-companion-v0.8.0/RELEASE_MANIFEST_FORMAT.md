# Controller release manifest format

`controller-release-manifest.json` schema version 1 identifies a release by tag, semantic/display version, monotonic sequence, channel, commit, publication time, repository, package identity, compatibility, lifecycle, preservation rules, and an unbounded component array.

Each component declares its ID/type, package-relative source, trusted destination root (`bar-data` or `companion`), destination-relative path, SHA-256, byte length, replace/remove policy, lock/restart/reset flags, optionality, platform/architecture, and configuration behavior. Publisher, installer, updater, transaction engine, and Recovery Mode iterate these records; they do not assume a widget, executable, or override count.

Absolute/traversal paths, duplicate destinations/IDs, unknown schema/roots, missing files, mismatched hashes/lengths, and components overlapping preserved configuration are rejected. The GitHub sidecar authenticates the outer ZIP. The embedded manifest uses an explicit detached identity sentinel because an archive cannot contain its own final digest; it still authenticates every payload component.

The package also includes `installed-release-bootstrap.json`, a non-authoritative release/component identity template. The installer/updater completes it using the detached outer-package and manifest hashes and writes authoritative `installed-release.json` only after a successful transaction.
