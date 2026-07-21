# Radial typography architecture

`controller_ui_shared_renderers.lua` owns the semantic `RadialStyle` contract and the only radial drawing implementation used by gameplay and authoring previews. Its roles are `categoryLabel`, `centerTitle`, `centerDescription`, `metalCost`, `energyCost`, `metadata`, `footer`, `pageIndicator`, `slotNumber`, and `unavailableText`.

Settings remain flat in schema 3 for backward-compatible validated merging. `RadialStyle.Resolve` converts the flat global/per-component values into the role model. `Controller UI Layout` caches one resolved table per radial and settings revision, avoiding per-frame style allocation. The camera widget receives that cached table from `WG.ControllerUISettings.GetResolvedRadialStyle`.

Resolution order is built-in fallback, bundled/cached shipping default, global personal value, explicit per-radial personal override, allowed enforced remote value, then unsaved authoring preview. Turning `typographyOverride` off immediately returns the radial to global inheritance; per-radial stored values remain available if the user later re-enables the override.
