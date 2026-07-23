# Disassemble Shared Reclaim

v0.8.1 makes the native tactical reclaim executor the one-shot reclaim path for Disassemble.

The selected helper chain is:

1. `ControllerCameraTestGetReticleNativeReclaimCommandTarget()`
2. `ControllerCameraTestIssueDisassembleSingleReclaim(target, source)`
3. `ControllerCameraTestExecuteTacticalCommand(option, false, nil, target)`
4. `ControllerCameraTestIssueOrderToSelectedUnits(CMD.RECLAIM, params, "Reclaim", targetName)`

The target override is important. It preserves the target captured on the controller edge so a later nil trace cannot turn a valid tap into an area reclaim or a no-op. Unit targets and feature targets are encoded through the same tactical command executor; constructor IDs are rejected as reclaim targets before issuing.

Shared callers:

- Native Disassemble wrapper: `ControllerCameraTestIssueNativeDisassembleTarget()`
- Native Disassemble `LB+A`
- Legacy Disassemble `LB+A`
- Disassemble `X` short tap over a valid reclaimable target

The helper restores staged constructors, validates reclaim-capable selected constructors, issues one command, avoids the native target modal, avoids area anchors by clearing `hasWorld` on single targets, and resets the Disassemble double-B candidate after a reclaim attempt.

