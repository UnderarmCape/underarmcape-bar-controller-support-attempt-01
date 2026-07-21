# Radial typography architecture

`controller_ui_shared_renderers.lua` remains the single renderer for gameplay and authoring previews. Its semantic roles are `categoryLabel`, `centerTitle`, `centerDescription`, `metalCost`, `energyCost`, `healthStat`, `availabilityText`, `metadata`, `footer`, `pageIndicator`, `slotNumber`, and `unavailableText`.

The v0.7.0 renderer measures icon/number rows before placement, preserving independent metal, energy, health, and availability typography and avoiding overlap at large values or scales. Dedicated BAR-derived icon paths prevent collisions. Build resource deficits are distinct from engine-disabled availability reasons; page and category context remain, while internal button footer prompts are intentionally absent.

`controller_ui_runtime.lua` loads bundled/cached defaults, merges migrated personal settings, resolves radial styles, and owns the normal hint registry. The optional layout widget attaches to this service only when manually enabled. Resolution order remains built-in fallback, bundled/cached defaults, personal value, allowed enforced remote value, then an optional live authoring preview.
