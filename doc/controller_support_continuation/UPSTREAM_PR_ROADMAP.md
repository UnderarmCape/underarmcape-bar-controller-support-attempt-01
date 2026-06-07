# Upstream PR Roadmap

## Recoil Engine

Upstream the native controller/gamepad input APIs used by the custom
controller-enabled Recoil engine. The custom engine requirement remains until
that support is merged and adopted by BAR.

## BAR Area Mex API

Current PR:
https://github.com/beyond-all-reason/Beyond-All-Reason/pull/7874

The target API is:

`WG.controllerAreaMex.issueArea(x, y, z, radius, opts)`

Keep shipping `cmd_area_mex.lua` until the upstream API or an equivalent is
available in the BAR version users actually run.

## BAR Pregame API

Upstream or replace the small `WG.pregameui` controller Ready/Lock API.
Keep shipping `gui_pregameui.lua` until that owner-controlled semantic action
is available upstream.

## Future Controller Metadata

Longer-term BAR work may expose formal controller command metadata, default
bindings, and reusable APIs for area commands and UI activation.
