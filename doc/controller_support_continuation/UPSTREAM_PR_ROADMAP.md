# Upstream PR Roadmap

This roadmap documents the three main lanes of integration required to merge controller support into vanilla Beyond All Reason (BAR) and standard Recoil engine.

---

## Lane 1: Recoil Engine PR
- **Objective**: Upstream native controller/gamepad input APIs directly into the Recoil engine.
- **Current Status**: Development currently relies on a custom controller-enabled Recoil engine (packaged in v0.4.3 AIO).
- **Goal**: Once the engine PR is merged and officially adopted by BAR, users will no longer need custom engine overrides or modified binaries to use a controller.

---

## Lane 2: BAR Lua PR (`cmd_area_mex.lua`)
- **Objective**: Expose a controller-safe Area Mex API bridge in vanilla BAR.
- **Implementation**: Add `WG.controllerAreaMex.issueArea(x, y, z, radius, opts)` inside `cmd_area_mex.lua`.
- **Reasoning**: This allows the controller widget to issue Area Mex commands without modifying or shipping a custom version of `cmd_area_mex.lua`. All internal Area Mex calculations are preserved inside the vanilla widget.

---

## Lane 3: Future BAR Lua/UI PRs
- **Objective**: Introduce formal controller command metadata, bindings libraries, and options.
- **Future Goals**:
  - Expose API bridges for other area commands (e.g. Repair, Reclaim, Restore, Resurrect).
  - Clean implementation of a controller command library/registry inside BAR.
  - Expose default controller bindings inside the game settings UI.
