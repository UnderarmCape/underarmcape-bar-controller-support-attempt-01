# Pull Request Notes: Area Mex Controller API Bridge

## Purpose
Add a controller-safe `WG.controllerAreaMex.issueArea` API to BAR Area Mex.

## Why
Allows the controller UI to pass center coordinates and radius directly without duplicating Area Mex internals or spot selection logic.

## Preserves
- Mouse Area Mex `CommandNotify` behavior is completely unchanged.
- Existing custom installer and modoptions behavior is unchanged.

## Current Mod Dependency
Until this is upstreamed, controller releases must ship a modified `cmd_area_mex.lua`.

## Future
Once merged upstream, controller releases should no longer need to include a modified `cmd_area_mex.lua` for Area Mex support.
