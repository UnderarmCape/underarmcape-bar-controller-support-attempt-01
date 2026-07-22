# Disassemble target model

Inside Disassemble, X immediately issues native Reclaim for a valid unit or
feature. Empty ground issues Move. A non-empty non-reclaimable target does not
fall through to Move.

Native target collection excludes only the current constructor set and dead or
invalid units; it does not apply a friendly-selection filter. Enemy units and
structures are therefore eligible for the same native Reclaim command. Enemy
area candidates are highlighted by Smart Area Reclaim's native overlay.

Touching an eligible own mobile constructor adds it to the reclaimer set. It is
not added to the target set, and factories remain excluded. Constructor
selection is restored before commands are issued, and a successful Reclaim
refreshes the existing inactivity timer without leaving Disassemble.
