# Known Limitations and Deferred Work

This document details known limitations of the v0.4.5 release and deferred development items.

---

## 1. Multi-Unit X Drawn-Path Movement
- **Status**: Reverted / Disabled.
- **Context**: The experimental implementation of controller-native path sampling and unit distribution caused the main controller widget (`gui_controller_camera_test.lua`) to fail loading in-game.
- **Future Path**: Retry this feature only on a separate, dedicated experimental branch. The recommended future approach is to inspect and reuse vanilla custom-formation APIs rather than writing a standalone sampler, or to write isolated diagnostics first.

---

## 2. Engine Override Requirement
- **Status**: Required.
- **Context**: The v0.4.5 release still requires the custom controller-enabled Recoil engine build (released in the v0.4.3 AIO installer package) to parse gamepad inputs.
- **Future Path**: Merge gamepad APIs directly into mainstream Recoil Engine (see Lane 1 of Upstream PR Roadmap).

---

## 3. Modified BAR Widgets
- **Status**: Required.
- **Context**: We must ship a modified version of `cmd_area_mex.lua` to serve as an API bridge for controller Area Mex commands.
- **Future Path**: Submit a PR to upstream the bridge function directly to BAR (see Lane 2 of Upstream PR Roadmap).
