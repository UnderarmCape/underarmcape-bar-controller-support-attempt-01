# Enemy Disassemble targets

Disassemble separates command sources from reclaim targets. Owned eligible
constructors are cached as reclaimers. Own units may also be represented by
vanilla selection; enemy and otherwise unselectable units/structures live in
the native `markedTargets` collection and use the native Disassemble highlight
path. Enemy constructors are targets. Factories/labs never become reclaimers.

An exact enemy reticle target can receive immediate X Reclaim or LB+A tap
Reclaim. LB+A hold can use it as the UnitDefID anchor for native same-type area
Reclaim. Hold-A scans the engine cylinder without an allied-only filter;
RT+Hold-A merges the scan into existing marked targets. Batch dispatch combines
selected own targets and marked targets, deduplicates them, preserves cached
constructors, and resets inactivity only after an accepted Reclaim.

No new teammate filter is introduced. BAR's native command eligibility and
engine rejection remain authoritative, and accepted Disassemble actions do not
exit the mode or fall through to Move.
