# Vanilla idle-unit navigation

D-pad Left calls `WG.idlebuilders.controllerPreviousIdleUnit`; D-pad Right calls
`controllerNextIdleUnit`. LB+D-pad uses the corresponding previous/next type
entry points. These explicit APIs wrap the live Idle Builders widget's
`controllerCycle`, rather than a controller-maintained unit list.

The widget refreshes its real `idleList`, preserves `existingIcons` type and
within-type order, prunes invalid/dead/non-idle entries, selects the chosen
unit, calls `viewselection`, plays the native right-click sound, forces the
native icon refresh, and exposes the same controller highlight in its draw
path. The camera stores only diagnostics.

Active radial, settings, pregame, or other modal D-pad ownership runs first. If
the widget has not registered yet or has no valid entries, cycling is a safe
no-op and no fallback list is created.
