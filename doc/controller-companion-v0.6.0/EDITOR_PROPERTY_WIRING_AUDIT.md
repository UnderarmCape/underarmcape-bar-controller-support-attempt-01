# Controller UI Authoring property-wiring audit

Audit baseline: `1058ae73a0`. Release defaults: schema 3, revision `0.6.0-3`. “Working” means the property reaches a production draw/layout/state path; “repaired” means it was disconnected or generic at the baseline and is now asserted by a release test.

## Property matrix

| Family | Properties | Classification and production effect |
|---|---|---|
| General | `enabled`, `resolutionAware`, `scale`, `opacity`, `fontScale`, `safeMargin` | Working. Gate all controller UI and feed effective layout, alpha, typography, and safe bounds. |
| Hints: layout | `enabled`, `x`, `y`, `scale`, `iconScale`, `fontScale`, `rowSpacing`, `columnSpacing`, `iconTextSpacing`, `padding`, `maxWidth`, `columns`, `backgroundOpacity`, `textOpacity`, `borderOpacity`, `borderThickness`, `fadeDuration`, `compact` | Working/repaired. Every value feeds measured production bounds or final draw alpha. Revision 3 defaults panel fill and border to zero. |
| Hints: content | `mode`, `presentation`, `overflow`, `expanded`, `maxItems`, `showChip`, `showActionText`, `showRowBackground`, `showCategoryHeaders`, `showContextHeader`, `showSeparators`, `wrapLines`, `chordLayout`, `priorityHiding` | Working/repaired. Filtering is performed before the shared model; presentation/layout is performed by the shared renderer. |
| Hints: motion | `marqueeSpeed`, `marqueeDelay`, `marqueeGap` | Repaired. `Marquee` loops with a configurable gap; `Ping Pong` pauses at each end and reverses; both activate only on overflow and are clipped. |
| Hints: glyph | `glyphColorMode`, `glyphSpacing`, `glyphOpacity`, `glyphBackgroundEnabled`, `glyphBackgroundOpacity`, `glyphBorderEnabled`, `glyphBorderOpacity` | Repaired. Final atlas passes receive color, spacing, alpha, optional fill, and optional border. Defaults have no fill/border. |
| Hints: text shadow | `textShadowEnabled`, `textShadowOpacity`, `textShadowOffsetX`, `textShadowOffsetY`, `textShadowSpread`, `textShadowR/G/B` | Repaired. Efficient offset layers precede the final text pass. |
| Hints: glyph shadow | `glyphShadowEnabled`, `glyphShadowOpacity`, `glyphShadowOffsetX`, `glyphShadowOffsetY`, `glyphShadowSpread`, `glyphShadowR/G/B` | Repaired. Offset atlas passes precede the final glyph pass. |
| Hints: text glow | `textGlowEnabled`, `textGlowOpacity`, `textGlowSize`, `textGlowIntensity`, `textGlowR/G/B` | Repaired. Four bounded surrounding passes; off by default. |
| Hints: glyph glow | `glyphGlowEnabled`, `glyphGlowOpacity`, `glyphGlowSize`, `glyphGlowIntensity`, `glyphGlowR/G/B` | Repaired. Four bounded tinted atlas passes; off by default. |
| Hints: label background | `textBackgroundEnabled`, `textBackgroundOpacity`, `textBackgroundPaddingX/Y`, `textBackgroundBorderOpacity`, `textBackgroundBorderThickness`, `textBackgroundR/G/B` | Repaired. Fits only the action-label region and is independent from glyph, row, and panel backgrounds. |
| Hints: hold | `showHoldIndicator`, `holdStyle`, `holdLabelScale`, `holdLabelSpacing`, `holdOpacity`, `holdColorR/G/B`, `holdGlyphThickness`, `holdGlyphOpacity` | Repaired. `Bold HOLD` and `Hold Glyph` both use the live binding model. Tap actions never add TAP. |
| Actions | `actionTarget`, `actionVisible`, `actionCategory`, `actionOrder`, `actionShortLabel`, `categoryTarget`, `categoryVisible`, `categorySortOrder` | Working. Hooks update the live hint registry overrides, hidden-action set, ordering, categories, and labels. |
| Hot Slots: geometry | `enabled`, `x`, `y`, `scale`, `slotSize`, `slotWidth`, `slotHeight`, `slotGap`, `slotCount`, `orientation`, `rows`, `panelPadding`, `anchor` | Working/repaired. The production strip builds and draws the measured grid. `slotSize` is a documented convenience duplicate that atomically sets width and height; independent dimensions then take precedence. |
| Hot Slots: content/style | `showLabel`, `headerLabel`, `showStatus`, `showCounts`, `showAuto`, `showRole`, `hideEmpty`, `selectedBorderThickness`, `emptyOpacity`, `themeOverride`, `opacity`, `fontScale`, `iconScale`, `backgroundOpacity` | Working/repaired. Live model filtering and shared draw parameters are asserted. |
| Hot Slots: behavior | `autoCollapse`, `autoCollapseDelay`, `animationDuration`, `scrollBehavior` | Working. Visibility timing, fade, active-slot windowing, fixed/follow, and wrap are production-side behavior. |
| Launchers: Bindings | `enabled`, `x`, `y`, `scale`, `opacity`, `fontScale`, `width`, `height`, `anchor` | Working. `gui_controller_bindings_ui.lua` reads shared normalized bounds and effective appearance. The full Bindings window is untouched. |
| Launchers: UI Layout | `enabled`, `x`, `y`, `scale`, `opacity`, `fontScale`, `width`, `height`, `padding`, `backgroundOpacity`, `anchor` | Working. The layout widget draws and hit-tests the same effective bounds. |
| All Radials | `enabled`, `scale`, `opacity`, `fontScale`, `iconScale`, `centerTextScale`, `selectedScale`, `selectedBorderThickness`, `itemSpacing`, `legacyThemeOpacity`, `pageStatusVisible` | Repaired. The production camera owner merges these into every shared radial model. |
| Build/Factory/Tactical/Selection Radial | per-component `enabled`, `x`, `y`, `scale`, `opacity`, `fontScale`, `iconScale` | Repaired. Visibility, center, geometry, alpha, labels, center text, and icons use effective per-component plus all-radial values. |
| Selected Status | `enabled`, `x`, `y`, `scale`, `opacity`, `fontScale`, `iconScale`, `width`, `height`, `anchor` | Repaired. Panel matrix/bounds, alpha, font sizes, and factory/queue icon dimensions use effective values. |
| Queue and Placement Status | per-component `enabled`, `x`, `y`, `scale`, `opacity`, `fontScale` | Working. Production status draws already used the shared helpers. |
| Pregame, Notifications, Instructional, Companion Status | per-component `enabled`, `x`, `y`, `scale`, `opacity`, `fontScale` | Working. Production owners use shared visibility, center/bounds, alpha, and font helpers. |
| Reticle | `enabled`, `x`, `y`, `scale`, `opacity` | Working. Production reticle reads visibility, center, effective size, and alpha. |
| Themes | `preset`, `advancedColorEditor`, `colorTarget`, `colorHex`, `colorHue`, `colorSaturation`, `colorValue`, and `background/foreground/accent/muted/danger R/G/B` | Working. Presets and HSV/hex editors update the same theme table consumed by production; component theme overrides are applied to hot slots. |
| Favorites, saved values, component presets, profiles | UI actions rather than scalar property rows | Working. Stored in personal author data, not shipping locks; they filter/apply authoring rows without resetting personal settings. |
| Authoring | `snapEnabled`, `snapGrid`, `snapThreshold`, `showSafeArea`, `showOutlines`, `shortcutUndo`, `shortcutRedo`, `shortcutSave`, `shortcutDraft`, `shortcutPublish`, `shortcutSearch`, `shortcutClose`, `shortcutNext`, `shortcutPrevious` | Working. Canvas move/resize, guides, authoring chrome, and keyboard dispatch consume them. |
| Recovery | no scalar properties advertised | Working through explicit Recovery actions. Draft detection, restore, discard/reset, undo history, and personal save remain separate from production settings. |
| Debug | `debug.enabled` | Working as permission/visibility gate only. Actual Controller Debug visibility is session-only through the camera widget WG API and is excluded from defaults, remote enforcement, persistence, and undo. Internal authoring diagnostics have a separate `Author Diag` developer action. |
| Mouse Mode | no renderer properties advertised | Deliberately unsupported in this editor release. Existing Mouse Mode behavior and bindings are preserved; no disconnected appearance controls are shown. |

## Removed or hidden controls

- Removed `showTapHold`: TAP is never rendered; hold has dedicated controls.
- Removed aggregate `shadowEnabled` and `glowEnabled`: they were ambiguous and disconnected. Separate text/glyph controls replace them.
- Removed `fontMinScale`, `Shrink`, and `Truncate`: release modes are Wrap, Clip, Marquee, and Ping Pong.
- Removed `marqueeEnabled`, `marqueeMode`, and the mislabeled `Scroll`: overflow selection now directly enables the reliable mode.
- Removed `Text Chip + Action`: the glyph asset system is the supported button presentation. Text fallback remains automatic when a glyph/atlas is unavailable.

No exposed release property is accepted as a silent no-op. Unsupported Mouse Mode appearance and unavailable preview types advertise no scalar controls or substitute preview.

## Automated evidence

- `Test-ControllerUIReleaseQuality.lua`: effect layers, label background, motion timing, all polished radial styles, hot-slot layout parameters, revision-3 defaults, debug persistence exclusion, and wheel focus source assertions.
- `Test-ControllerUISharedRenderers.lua`: shared production/preview calls and measured model parameters.
- `Test-ControllerGlyphs.lua`: live sequences, no-TAP behavior, both hold paths, long chords, and square D-pad destination geometry.
- `Test-ControllerUIModalInput.lua`: hover/wheel browse, explicit value focus/edit, blur, real Controller Debug toggle, modal ownership, and keyboard input.
- Existing authoring/workspace/gameplay and companion suites cover precedence, personal overrides, undo/recovery, focus, publisher/default validation, and retained controller behavior.

