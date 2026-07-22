# Vanilla idle-unit navigation

D-pad Left/Right calls the live Idle Builders widget API. The API refreshes the
widget's real `idleList`, preserves `existingIcons` type ordering and within-type
unit ordering, prunes invalid/dead entries, selects the chosen unit, runs
`viewselection`, and plays the widget's normal selection sound.

LB+D-pad Left/Right cycles the same native type buckets. The camera stores only
diagnostic cursor fields; it does not scan team units or maintain a parallel
idle list. If Idle Builders is disabled or has no entries, the operation is a
safe no-op with a diagnostic result.
