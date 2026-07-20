# Controller UI authoring suite

## Scope and ownership

`Controller UI Layout` schema 3 owns layout, appearance, hint organization, personal authoring data, shipping drafts, and recovery. The gameplay widget still owns commands, bindings, controller state, and game-safe rendering. The full-screen Controller Bindings window remains geometrically and behaviorally unchanged.

Selectable controller surfaces include hints, both floating launchers, build/factory/tactical/selection radials, unit hot slots, selected/queue/placement status, reticle, notifications, pregame/instructional surfaces, companion status, and the editor. The gameplay debug panel has only an Advanced visibility gate; its established internal move/resize UI remains its owner.

## Editing workflow

- Open with `UI Layout`, `/luaui bar_controller_ui`, or the 1.5-second Back/View + Start/Menu hold.
- Click an outlined component outside the editor and drag it. Snapping considers safe-screen edges, screen centers, the configured grid, and other visible controller components.
- Components with real width/height fields expose a direct resize handle. Radials and derived-size surfaces use their safe scale/size properties.
- L/HC/R/B/VC/T align the selection. DH/DV distribute visible components.
- Property rows support click, held +/- acceleration, wheel, D-pad, Shift coarse adjustment, Ctrl fine adjustment, direct text editing, Home/End, Page Up/Page Down, and Delete reset/unpin.
- Basic, Advanced, All, Favorites, Recent, and Modified filters share a searchable, virtual-scrolled property list.
- Preview states cover Live, normal/nothing/single/multiple selections, builder/factory/transport, all radials, build placement, Mouse Mode, pregame, Bindings, Layout Editor, hot slots, and a synthetic long-binding stress test. Simulated states are marked and issue no game command.

## Hints and action organization

Context density modes are Contextual, Layered, Minimal, and Everything. Layered adds the underlying normal-gameplay layer after the active modal layer; Everything excludes developer-only stress hints.

Visual presentations are Glyph + Action Text, Text Chip + Action, Button Chip Only, Action Text Only, Background Only, Minimal Glyph, Compact, Full Descriptive, and Custom. Until artwork ships, glyph modes use abbreviated live-binding text chips.

Editable layers include chip/action visibility, overlay and row backgrounds, border thickness, separators, context/category labels, optional shadow/glow, Tap/Hold wording, chord layout, column count, spacing, opacity, scale, and font limits. Overflow choices include wrapping for 2–8 lines, shrink-to-minimum, truncation, optional loop/ping-pong marquee, expansion, tooltips, automatic abbreviation, custom short labels, multiple columns, and priority hiding.

The Actions tab edits each stable action's visibility, category, numeric order, and short label, plus category visibility/order. Shipping category/order values remain the baseline and personal overrides win unless a path is remotely enforced. Equivalent authoring APIs and `/luaui bar_controller_ui hint ...` commands are available for diagnostics and automation.

## Favorites, presets, themes, and color

- Pinned properties appear in Favorites.
- A saved property value carries a generated name and compatible property key.
- Component presets are named records with favorite/shipping flags. APIs and `preset save/apply/rename/duplicate/delete` commands support a multi-preset library.
- Profile export/import uses a versioned JSON document and writes a backup before import.
- Theme presets are BAR Default, Minimal, Compact, Large Accessibility, Transparent, High Contrast, Custom, Ocean, Soft, and Colorblind. Applying one changes compatible appearance values, not component positions.
- RGB plus synchronized HSV and hexadecimal copy/paste controls cover background, foreground, accent, muted, and danger. Recent colors are retained automatically and favorite colors are available through the authoring API. Hot slots additionally support a per-component theme override.

## Save, recovery, and shortcuts

Live preview is immediate. Explicit Save promotes settings and authoring data to the personal layer. Unsaved settings and action/preset edits stay in a separate recovery record. Undo/redo retain at most 60 snapshots; a held adjustment or drag is one transaction.

Default rebindable editor shortcuts are Ctrl+Z/Y/S, Ctrl+Shift+S (draft), Ctrl+Alt+S (explicit publish request), Ctrl+F, Escape, Tab, and Shift+Tab. Shortcut strings are separate from gameplay bindings and can be edited in Advanced or with `bar_controller_ui shortcut <name> <value>`.

## Developer Authoring Mode

Enable locally with `/luaui bar_controller_ui authoring on`. Remote JSON cannot enable it. Draft writes include settings, hint categories/order/labels, themes, named presets, and per-property/section enforcement. The E row control or `enforce <scope>.<property>` changes draft enforcement.

Draft writes are local only. Publish Request writes a separate explicit request; only an independently armed developer helper can act on it. Recovery and ordinary personal saves never create publish requests.

## Current renderer limits

- No controller artwork atlas is bundled, so glyph presentations remain text-chip based.
- Immediate-mode GL safely supports rectangular borders/shadow/glow, but not rounded corners, gradients, fade-edge clipping, or animated color cycles in this milestone.
- Category/action order uses reliable numeric controls and APIs rather than drag-and-drop.
- Per-category style copying and independent category panels are not implemented; shipping metadata currently carries category identity, order, and visibility, while the runtime renderer draws one combined panel.
- Saved-value naming uses a generated name in the compact in-game editor; richer rename/delete management is exposed for component presets, not every saved value.
