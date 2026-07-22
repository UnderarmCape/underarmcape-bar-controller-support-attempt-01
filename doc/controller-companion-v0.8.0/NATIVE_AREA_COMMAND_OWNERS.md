# Native area-command owners

The live failure was a state-copy bug, not hidden-panel suppression or missing
button edges. `controller_native_command_owner.lua` converted absent
`anchor`/`current` values into empty tables in `Owner:GetState()`. Area Mex and
Smart Area Reclaim interpreted those tables as a live preview and called
`gl.DrawGroundCircle` with nil coordinates. BAR removed both widgets after the
DrawWorld errors, leaving their retained preview/session path unable to receive
the second A/X confirmation.

`GetState()` now preserves nil for descriptor, anchor, and current. Area Mex,
Smart Area Reclaim, and the generic Order Menu owner also validate complete
x/y/z coordinates before drawing. The real widgets therefore remain loaded and
registered through anchor, neutral release, confirm, and close.

| Command family | Authoritative owner |
| --- | --- |
| Reclaim unit/feature/area | Smart Area Reclaim |
| Area Mex | Area Mex |
| Formation/front commands | Custom Formations |
| Other point, area, front, rectangle commands | Order Menu generic owner |

The camera is only the highest-priority input/reticle adapter. The owner keeps
its immutable descriptor and session token, builds final parameters, calls
`CommandNotify` once, and permits one direct engine fallback only when
unhandled. A→A, A→X, X→A, and X→X use the same fresh-release barrier. B cancels
without dispatch. Visual hiding suppresses Order/Build panel draw and mouse
interception only; Update, owner APIs, and confirmation remain active.
