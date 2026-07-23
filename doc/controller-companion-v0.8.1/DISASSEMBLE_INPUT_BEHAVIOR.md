# Disassemble Input Behavior

Disassemble keeps one local owner for A/X/B input.

`LB+A`:

- Press captures the current native reclaim target.
- Hold keeps the existing same-type area reclaim path for unit targets.
- Release before hold invokes `ControllerCameraTestIssueDisassembleSingleReclaim(state.lbA.targetInfo, source)`.
- Missing targets are skipped safely; selection and Move are not started.

`X`:

- Press records both `pending.targetInfo` and `pending.groundInfo`.
- Hold past `xHoldSeconds` restores constructors and enters single-unit path Move or moveLine drag.
- Release before hold reclaims when `pending.targetInfo` exists.
- Release before hold moves to `pending.groundInfo` when no reclaim target exists.
- The Disassemble owner consumes X, so normal Smart X does not run in the same edge.

`B`:

- If a Disassemble area, mark, LB+A, pending X, or shared area selection is active, B cancels that state and stays in Disassemble.
- If native selected units are not just the reclaimer set, B clears selection and stays in Disassemble.
- Consumed B presses reset `state.doubleB`.
- Only when selection and targeting are already clear can double-B exit Disassemble.

