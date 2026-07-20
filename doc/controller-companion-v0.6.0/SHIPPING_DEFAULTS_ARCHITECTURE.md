# Shipping defaults architecture

## Atomic source pair

The versioned files are `controller-ui/shipping-defaults.json` and `controller-ui/shipping-defaults-manifest.json`. The recommended public branch is `controller-ui-live-defaults`, containing those same two root-level names in one commit. Defaults can advance without rebuilding the companion or creating an application release.

Schema 3 defaults contain validated global/theme/authoring/component settings; hint categories, action order/category overrides, hidden actions and short labels; named themes and component presets; compatible mod version; and explicit enforcement data. The manifest contains schema and monotonically increasing revision, defaults version/file/hash, timestamps, compatibility, branch/channel, source state, and change summary.

## Resolution order

Lowest to highest:

1. built-in fallback values;
2. bundled shipping JSON;
3. a compatible companion-cached pair at the same or newer revision;
4. saved personal settings and action/category organization;
5. remote fields listed in `enforcedPaths` and `enforcedSettings`;
6. the current unsaved or recovered preview.

Ordinary edits reject an actively enforced path. Recovered preview remains visibly dirty and must be saved or reset. Developer Authoring Mode is always restored from local personal configuration and can never be enabled remotely.

## Companion handoff

The companion writes under `<BAR data>/LuaUI/Config/BARControllerSupport/`:

```text
controller-ui-defaults.json
controller-ui-defaults-manifest.json
controller-ui-defaults.previous.json
controller-ui-defaults-manifest.previous.json
reload-request.json
```

It validates manifest compatibility, SHA-256, schema, value ranges, and component/action/category IDs. A current or newer local revision is never downgraded. Before replacing a valid pair, it writes the previous known-good payload and manifest. The new payload is atomically replaced first and the manifest last.

The widget polls only the local reload request and developer publish-result files every two seconds. It never polls GitHub or changes the controller UDP protocol.

## Failure behavior

- Missing cache: use bundled/fallback.
- Malformed JSON, unknown IDs, invalid ranges, version mismatch, or hash mismatch: retain the valid cache.
- Timeout/offline: controller input and cached defaults continue.
- Unknown future schema: reject rather than guess.
- Unknown ordinary fields in a supported schema: ignore them while validating known structures.
