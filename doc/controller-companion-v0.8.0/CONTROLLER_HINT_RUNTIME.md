# Controller Hint Runtime

## Regression and restored source

Git history showed that v0.6.1 and v0.7 shipped the same two-column composition, spacing, readable shadows, and 14/20 nominal text/glyph metrics. The runtime regression had two parts: the glyph transition reduced perceived chip hierarchy, and the lean `Controller UI Runtime` used a different widget name from `Controller UI Layout`, so the prior larger personal hint profile was never loaded.

The experimental shipped profile keeps the proven v0.6.1 composition and shadows at a readable scale: overall 1.25, text 1.15, glyph 1.25, and spacing 1.10. Xbox and PlayStation atlases are retained; their alpha bounds and aspect ratios match the legacy atlas, so no artwork reversion was needed.

## Persistence and migration

With no Runtime config, the enabled lean widget reads only the legacy Layout widget’s saved hint component from `widgetHandler.configData` and persists it under Runtime on the next save. This works while Layout stays disabled. Clearly custom values are copied exactly. A Runtime personal profile matching every old small appearance default (`1/1/1`, row 5, column 18, glyph-text 8, padding 12, and no spacing scale) migrates to the new shipped appearance; any mismatch is treated as intentional customization.

## Bindings UI controls

The normal Controller Bindings UI has a compact **Hints** settings page:

- Hint Overall Scale: 0.75–2.50, step 0.05
- Hint Text Scale: 0.75–2.00, step 0.05
- Hint Glyph Scale: 0.75–2.00, step 0.05
- Hint Spacing: 0.75–1.75, step 0.05
- Reset Hint Appearance

Changes call the lean runtime directly and are stored as personal settings. Text and glyph scales remain independent. Spacing scales row, column, panel padding, and glyph-to-text gaps. Reset removes only appearance overrides and resolves the experimental shipped defaults. Rendering remains single-owner and performs no per-frame texture loading.

## Stable update model

Passive reticle hover and target identity are no longer part of the hint context
signature. Radial open/close, targeting transitions, queue state, Disassemble,
and other explicit button-driven changes rebuild immediately. Actual selection
changes use a 0.16-second debounce. A model equal to the current model does not
increment the revision or rebuild draw data.

Controller Debug exposes model revision, last update reason, update timestamp,
and update count/rate. Hover can still change reticle and native target visuals
without changing hint text. Existing hint scale and spacing persistence remains
fully functional.
