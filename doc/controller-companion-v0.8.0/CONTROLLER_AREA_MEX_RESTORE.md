# Controller Area Mex Restore

Area Mex uses the v0.6 two-confirm gesture in `gui_controller_camera_test.lua`. Final confirmation calls:

```lua
WG.controllerAreaMex.issueArea(x, y, z, radius, { shift = queueHeld })
```

The native `cmd_area_mex.lua` override owns metal-spot discovery, compatible constructor and extractor selection, existing-queue checks, preview-command generation, sorting, and `resource_spot_builder.ApplyPreviewCmds`. The camera widget does not duplicate this algorithm and never relies on Spring mouse-drag parameters.

The direct API rejects non-finite coordinates and non-positive radii. B cancels before dispatch, and the fresh-confirm edge produces at most one call.
