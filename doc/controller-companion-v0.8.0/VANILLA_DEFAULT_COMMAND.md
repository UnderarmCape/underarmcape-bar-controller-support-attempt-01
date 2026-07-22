# Vanilla default command for Smart X

Native Experimental Smart X calls `Spring.GetDefaultCommand()` at the current
controller reticle target. The resulting live command ID is reconciled against
Order Menu's enabled descriptors and dispatched through its single
`CommandNotify`/engine boundary.

There is no controller-owned priority table for Repair, Reclaim, Guard,
Attack, or Move in this path. Consequently air constructors use BAR's default
Repair resolution, enemy units and structures can resolve to Reclaim where BAR
allows it, and disabled or unavailable commands are rejected by the native
model. Legacy Controller UI retains the prior heuristic fallback.
