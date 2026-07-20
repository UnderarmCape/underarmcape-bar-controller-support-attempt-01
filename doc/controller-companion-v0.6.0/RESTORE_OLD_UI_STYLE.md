# Restoring the Controller UI visual identity

## References

The visual reference is the production drawing retained in `gui_controller_camera_test.lua` at the v0.5.1 release (`a6e03ab500`, tag `controller-support-v0.5.1-gameplay-fixes`) plus the richer build information-panel work in `8990aaa435`. The exact pre-shared-renderer tactical, selection-filter, build/factory, and controller-group draw paths were still present below the early shared-renderer returns at the start of this task (`1058ae73a0`). The generic conversion being corrected was introduced by `e06abd48a7`.

Reference files:

- `luaui/Widgets/gui_controller_camera_test.lua`: original production geometry, state colors, information panels, page labels, group slots, and live model collection.
- `luaui/Include/controller_ui_shared_renderers.lua`: shared production/preview renderer introduced in v0.6.0 and repaired in this release.
- `luaui/Widgets/gui_controller_ui_layout.lua`: authoring settings and synthetic preview-model ownership.

## Restored elements

- Build and Factory use the original colored circular backdrop, ring, square build icons, affordability treatment, selected border, queue badges, center information panel, category, and page status.
- Tactical uses its category-color backdrop and ring, rectangular command cards, selected-card treatment, category chips, and center command/status hierarchy.
- Selection uses its four-way filter compass, individual filter colors, strong selected filter, and compact center instructions.
- Controller Groups uses the prior strip structure, dark hierarchy, blue active slot, gold recent/active border language, unit image, slot number, count, AUTO marker, concise header, and status line.

The legacy fallback code remains only as a recoverability reference. Normal production and authoring previews both call `controller_ui_shared_renderers.lua`; no second preview renderer was added.

## Intentional changes

- Radial inputs are data models (`build`, `tactical`, and `selection`) instead of renderer-local game-state reads.
- Layout settings now modify the legacy style: global/per-radial scale and opacity, position, icon and label scale, center-text scale, selected scale/border, item spacing, legacy color-layer opacity, and page/status visibility.
- Hot slots retain their original default appearance while supporting position, orientation/grid rows, dimensions, gap, visible count, icon/text scale, empty filtering, theme override, and collapse animation.
- Hint presentation is deliberately redesigned separately; it does not change radial or hot-slot identity.

## Shared-path guarantee

Production widgets collect real commands, queue counts, filters, group contents, and textures. The editor creates synthetic values with the same model fields. Both send those models and the effective authoring settings to the same measured draw functions. Automated tests assert the production calls, style dispatch, measured parameters, and preview reuse.

