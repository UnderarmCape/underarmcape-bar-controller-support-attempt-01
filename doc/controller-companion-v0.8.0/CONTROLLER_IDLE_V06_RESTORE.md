# Controller Idle v0.6 Restore

The ordered IDs from `WG.idlebuilders.controllerGetLiveIdleEntries()` are the sole idle source. D-pad Right and Left apply the v0.6 modulo traversal directly to that live list and focus/select the resulting exact unit ID. No mouse-click wrapper is involved.

If the remembered unit dies, becomes busy, changes team, or disappears, it is absent from the next ZZZ snapshot; traversal repairs from index zero and wraps safely. Unit ID and UnitDefID are remembered after each successful choice.

LB+D-pad Down is the retained enhancement. It selects only the current snapshot’s idle entries whose UnitDefID matches the remembered type, excluding every busy/dead/non-idle same-type unit by construction.
