# BAR Controller Support v0.8.3

Release tag: `controller-support-v0.8.3-smartx-insert-tactical-repair`

Package: `BAR_Controller_Support_v0.8.3_SMARTX_INSERT_TACTICAL_REPAIR.zip`

- Smart X now repairs valid damaged friendly units directly on normal X tap, with Hold-X movement preserved.
- Y Repair is removed from bindings, defaults, hints, validator known-actions, and active tests.
- RB+A is the single insert chord for factory/lab focused build insertion and compatible command/build queue-front insertion.
- Disassemble resolves L3+R3 Clear Queue, LB+B Stop, LB+A tap/hold reclaim, X, then B/double-B.
- Same-target double-tap A survives first-tap selection changes and transient nil hover.
- Hold Position / Move State and Wait keep Tactical open and refresh visible state.
- Self Destruct remains protected and requires the armed Back/View+L3+R3 hold.

Validation target: 115 v0.8.3 source checks plus release package, deployment, rollback, and GitHub publication verification.
