# Companion defaults and application update flow

## Startup

The bridge starts controller UDP immediately and runs one background update check with a 2.5-second timeout. It checks the defaults manifest and latest public release once; there is no periodic GitHub polling and no automatic application install.

A compatible newer defaults pair is downloaded, validated, backed up, and installed atomically. A same/newer cached revision is never downgraded. DNS, HTTP, timeout, malformed JSON, unknown IDs, range, compatibility, or hash failures retain the previous cache and controller bridge operation.

A newer application release only records availability and prints the manual command. Download and apply require separate approval; startup never replaces a running executable.

## Manual console commands

```text
BARControllerBridge check
BARControllerBridge defaults
BARControllerBridge update
BARControllerBridge status
BARControllerBridge reload
BARControllerBridge help
```

- `check`: defaults sync plus release discovery.
- `defaults`: defaults only.
- `update`: release only; prompt before verified download and again before installer launch.
- `update --yes`: approve download, not apply.
- `update --yes --apply`: explicitly approve both verified download and installer launch.
- `status`: installed version, cache/check/release/error state.
- `reload`: atomically write the Layout widget's reload request.

`--bar-data <path>` supports nonstandard BAR data. `--timeout-ms <250..120000>` is for manual diagnostics.

## Integrity and approval

Defaults require matching manifest/payload version and SHA-256, supported schema/companion version, known component/action/category IDs, and valid ranges. The previous valid pair is stored as `*.previous.json` before replacement.

Application packages require GitHub's `sha256:` asset digest or a matching `.sha256` sidecar. Missing or mismatched integrity metadata fails closed. The installer's optional network package path applies the same rule. BAR.exe is never modified.

The public companion stores no GitHub credential. Its endpoint/program-data environment overrides are test harness hooks, not credential or publishing switches. Publishing exists only in the separate developer helper and existing `gh` session.

## Automated coverage

The local .NET 5 harness uses loopback HTTP and isolated temp directories. It covers a valid pair, newer revision, prior-pair backup, downgrade prevention, malformed JSON, hash mismatch, unknown action ID, bounded timeout/offline cache, newer release reporting without apply, and reload handoff. It makes no GitHub request and touches no real BAR data.
