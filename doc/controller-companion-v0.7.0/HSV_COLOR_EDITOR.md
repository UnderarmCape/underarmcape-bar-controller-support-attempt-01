# HSV color editor

Compatible color rows use a compact current-color preview followed by Hue (0–360°), Saturation (0–100%), Value (0–100%), and Alpha (0–100%) sliders. Each channel supports dragging, exact entry, keyboard adjustment, and explicitly focused wheel adjustment. Shift is coarse and Ctrl is fine. Hover never edits a value; clicking elsewhere or Escape clears wheel-edit focus.

Twenty built-in swatches cover neutral colors, the main spectrum, BAR Accent, Metal, yellow Energy, Warning, Success, Disabled, and Selected. Favorite and recent custom colors appear as additional swatches. Every swatch is clickable, keyboard-focusable, named by tooltip, and applied as one undo operation. Copy and paste use exact `#RRGGBB` or `#RRGGBBAA` values.

A mouse drag opens one history transaction and commits it on release. Undo returns to the pre-drag color and redo reapplies the completed drag.
