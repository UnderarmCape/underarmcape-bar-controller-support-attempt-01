# Build and Factory selected border

`buildSelectedBorderScale` now reaches the production Build/Factory radial
renderer as `selectedBorderThickness`. The value is clamped to 1–18 pixels.
The selected cell draws an outside low-alpha halo and the primary border
without reducing the unit icon rectangle, so values above 1.0 are visibly
different at runtime.

This setting is intentionally confined to Build and Factory radials. Tactical
outer buttons use Order Menu's renderer and do not read the build-border
setting. The existing settings UI, persistence, reset, and live-update paths
remain unchanged.
