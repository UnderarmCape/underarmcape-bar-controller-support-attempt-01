# Vanilla Idle Builders navigation

The live Idle Builders widget now has one internal `activateIdleEntry` action shared by its clickable icons and controller entry points. It refreshes the real `idleList`, selects only live idle units, optionally sends `viewselection`, plays the same left/right click sound, updates the icon highlight, and forces redraw.

D-pad Left calls `controllerActivatePreviousEntry`; D-pad Right calls `controllerActivateNextEntry`. Traversal uses the widget's sorted `existingIcons` and each current idle bucket, including wrap. The camera stores diagnostics only and owns no idle inventory.

Mouse icon actions and controller actions both update remembered `unitID` and `unitDefID`. On list refresh, a missing unit repairs to another current idle unit of the same type; if none remains, focus clears. Dead, busy, under-construction, or otherwise non-idle units cannot persist.

LB+D-pad Down calls `controllerActivateAllFocusedType`. It selects the current live bucket for the remembered type, focuses the camera with `viewselection`, preserves native sound/highlight behavior, and safely does nothing without valid focus. Active radials, settings/modal UI, placement, and higher-priority modes consume D-pad first.
