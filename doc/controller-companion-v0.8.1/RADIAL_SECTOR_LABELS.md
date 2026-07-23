# Radial Sector Labels

Mixed-page sector labels now carry an explicit `labelColor` separate from sector fill/accent.

Renderer changes:

- `controller_ui_shared_renderers.lua` uses `sector.labelColor or sector.accent or accent`.
- A dark shadow pass is drawn behind the sector label.
- The bright foreground label is drawn over the shadow.

Palette changes:

- Combat uses a brighter red/orange accent and a lighter label color.
- Utility uses a brighter blue-violet accent and a lighter label color.
- Build, Constructors, Economy, and other mixed sectors use the same label/shadow treatment.

Mixed pages keep the large combined category heading hidden. One-category pages retain their large category title.

