# Migration and known limitations

Schema 3 is retained. On upgrade, the complete saved `Controller UI Layout` value is copied to `Controller UI Runtime` only if runtime data is absent; the original authoring value remains intact. Valid personal values win over missing v0.7.0 defaults, including exact hint and Bindings-button coordinates, radial typography/colors, themes, profiles, presets, favorites, and recents.

The old authoring widget is installed but disabled at order `0`; manual F11 enablement is still supported. Normal gameplay uses the lean runtime and has no editor polling, preview rendering, modal ownership, or launcher button.

Friendly area reclaim emits deterministic unit-target `CMD.RECLAIM` orders: the first replaces the captured reclaimers' reclaim queue and subsequent targets use the shift option. It does not reclaim enemies or unrelated unit types. Exact font metrics can vary with BAR runtime fonts. Independent .NET single-file publishes are not claimed byte-identical; one tested binary set is hash-frozen, then package staging is required to be deterministic.
