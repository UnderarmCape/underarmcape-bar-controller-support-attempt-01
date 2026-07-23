# Affordability Warning Display

The v0.8.1 affordability warning keeps raw affordability logic separate from center-text presentation.

Display parameters:

- sample interval: `AFFORDABILITY_DISPLAY_SAMPLE_SECONDS = 1.0`
- smoothing alpha: `AFFORDABILITY_DISPLAY_ALPHA = 0.35`
- display rounding: nearest 10

Behavior:

- Raw metal/energy deficits still drive disabled overlays and queue decisions immediately.
- Center text uses `ControllerCameraTestGetSmoothedBuildAvailability(option)`.
- Display samples at most once per second per build option.
- Positive smoothed deficits round to the nearest 10.
- Affordable items clear `menu.affordabilityDisplay[key]` immediately, so stale `NEED X ENERGY` text disappears without waiting for the next sample.

