# v0.6 Idle Navigation Restore

Ordinary D-pad Left/Right idle navigation is restored from the v0.6 behavior.

The controller enumerates own-team units, filters finished mobile idle candidates, prefers idle builders, falls back to other idle mobile units, sorts the list, and wraps previous/next selection with direct camera focus.

It no longer depends on `WG.idlebuilders.controllerGetLiveIdleEntries()` for ordinary Left/Right. LB+D-pad Down remains an extension that selects all currently idle units in the remembered UnitDefID bucket from the same restored idle list.
