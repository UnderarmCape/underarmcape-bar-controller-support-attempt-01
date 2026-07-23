# v0.8.4 Disassemble Target Ownership

Friendly Disassemble targets use Spring selection and BAR's native selected-unit visuals. Enemy Disassemble targets remain controller-owned marked targets and are never placed into the player's vanilla selection.

Mixed collections are still allowed. A tap, double-tap, Hold-A brush, and LB+A target collection can combine friendly selected targets with enemy marked targets. LB+A tap reclaims the full collection first; only an empty collection falls back to the captured one-shot reticle target.

LB+Hold-A anchors a same-type area reclaim on the captured UnitDef. Releasing to neutral arms resizing, A/X confirms, B cancels, and the mode remains active.

B clears active areas, enemy marks, and friendly Disassemble selection before double-B exit can arm. LB+B Stop and L3+R3 Clear Queue keep priority and stay in Disassemble.
