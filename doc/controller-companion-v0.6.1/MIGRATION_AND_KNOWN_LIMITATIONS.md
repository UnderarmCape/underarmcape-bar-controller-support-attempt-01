# Migration and known limitations

Schema 3 is unchanged. Existing radial scale, position, theme, per-component settings, custom colors, favorite/recent colors, profiles, presets, and bindings are preserved. Missing semantic values are filled from v0.6.1 shipping defaults. The old single `fontScale` continues to multiply role sizes, providing a stable migration for existing users.

The renderer uses the engine's installed font and outline support, so exact glyph width and weight can vary slightly with BAR font/runtime changes. Letter spacing is implemented for category labels; other roles use native font spacing. The .NET 5 single-file toolchain is not assumed to reproduce byte-identical bundles across independent publishes, so release binaries are built once, smoke-tested, hash-frozen, and deterministically staged from those frozen inputs.
