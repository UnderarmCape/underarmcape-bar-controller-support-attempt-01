# Installation and Manual Testing

## AIO Install

Download the v0.4.6 BAT, README, release notes, and both payload ZIPs into the
same folder. Do not manually extract the payload ZIPs.

Run:

`Install_BAR_Controller_Support_v0.4.6_AIO_CLEAN_INSTALL.bat`

Validate without changing the live install:

`Install_BAR_Controller_Support_v0.4.6_AIO_CLEAN_INSTALL.bat --payload-check`

## Manual Widget Path

`C:\Users\kaili\AppData\Local\Programs\Beyond-All-Reason\data\games\BAR.sdd\luaui\Widgets`

All five current widgets must be copied together.

## Priority Smoke Tests

- [ ] Payload check succeeds.
- [ ] BAR launches in Singleplayer: Beyond All Reason Dev.
- [ ] A/X places commander and activates Ready.
- [ ] Back + Start toggles Mouse Mode.
- [ ] Back tap cycles all speed presets.
- [ ] Cursor clamps at all screen edges without recenter or edge-pan.
- [ ] Pregame LB + right stick rotates/tilts.
- [ ] Pregame LB + LT + right stick Y zooms.
- [ ] Build/factory radial shows title, role, and stats.
- [ ] Factory insert-to-front still works.
- [ ] T2 mex and geothermal upgrades still work.
- [ ] Air transport controls still work.
- [ ] Area Mex, Repair Area, and Reclaim Area still work.
- [ ] No Lua or OpenGL stack errors occur.
