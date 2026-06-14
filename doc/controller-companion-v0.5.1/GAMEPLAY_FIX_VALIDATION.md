# BAR Controller Support v0.5.1 Gameplay Fix Validation

This note covers the local Pass 2 Lua gameplay fixes built on the published
v0.5.0 Widget + Companion baseline. It does not change or replace the v0.5.0
release package.

## Validated fixes

1. Area Mex appears in the tactical radial only when the current selection
   contains a constructor whose runtime constructor record or unit definition
   confirms it can build a metal extractor. The controller enables the existing
   Area Mex helper on demand if BAR has it disabled.
2. Normal hold X with a multi-unit selection starts a Move line, not a Fight
   line. Smart X tap behavior and explicit Fight inputs remain separate.
3. Smart X on an existing T1 mex uses `Spring.GetUnitBuildFacing` when
   available, with a safe facing-zero fallback, instead of calling the absent
   `Spring.GetUnitFacing` API.

## Manual validation result

- Move path fix: passed.
- Smart X T2 constructor on an existing T1 mex: passed with no widget crash.
- Normal Smart X, build menu, general radials, and companion flow: passed.
- Area Mex appears for eligible constructors and commanders: passed.
- Area Mex remains absent for non-mex-capable units: passed.

The live BAR widget configuration recorded `Area Mex` with order `0`, meaning
the packaged user widget was disabled. The first fix required its
`WG.controllerAreaMex.issueArea` API before adding the radial entry, so
eligible constructors were filtered out. This follow-up derives visibility
from constructor capability and queues the existing Area Mex widget for
enabling when needed.

## Manual regression test

1. Launch BAR through the normal patched shortcut.
2. Confirm the companion bridge connects and controller input works.
3. Select a builder, constructor, or commander that can build a mex.
4. Open the tactical radial, choose Tactical Actions with D-pad Down, and
   confirm Area Mex appears.
5. Select Area Mex, place its center/radius, and confirm it issues through the
   existing Area Mex helper.
6. Close and reopen the radial with the same eligible selection and confirm
   Area Mex remains present after the helper has loaded.
7. Select units that cannot build a mex and confirm Area Mex is absent.
8. Select multiple mobile units, hold X, draw a path, and confirm Move orders
   are issued instead of Fight orders.
9. Confirm a normal Smart X tap still performs the expected context action.
10. Confirm explicit Fight commands still issue Fight orders.
11. Select a T2 construction bot and use Smart X on an existing T1 mex.
12. Confirm the upgrade is issued or fails gracefully without removing the
    Controller Camera Test widget.
13. Confirm the build menu and other radial commands still work.
14. Inspect `infolog.txt` for new Lua errors and, on the first eligible radial
    open, at most one Area Mex helper enable message.

## Automated checks

Run `luac -p` on each changed Lua file and `git diff --check`. No BAR process
should be launched by automated validation.

Results on 2026-06-14:

- `luac -p luaui/Widgets/gui_controller_camera_test.lua`: passed.
- `git diff --check`: passed.
- Targeted source assertions for Area Mex eligibility, normal X Move mode,
  preserved explicit Fight mode, and removal of `Spring.GetUnitFacing`: passed.
- Follow-up assertions confirmed Area Mex visibility no longer requires
  `WG.controllerAreaMex` to exist before the radial cache is built.
- Follow-up assertions confirmed eligible `UnitDef.buildOptions` are checked
  for metal extractors and the existing `Area Mex` widget is queued for
  enabling through `widgetHandler:EnableWidget`.
- Live root-cause evidence was confirmed in `LuaUI/Config/BYAR.lua`:
  `["Area Mex"] = 0`.
- The published v0.5.0 ZIP and checksum file still match SHA256
  `584f20ad10afdfbb35ccab247b69f0173c72ea6a7388ba01c3597cd0cef7213e`.
- `luacheck` was not available in the local toolchain.
- BAR was not launched during automated validation.
