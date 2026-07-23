# Controller Input Priority

v0.8.1 keeps one widget-level input owner and preserves one branch per controller edge.

A priority:

1. Active tactical point/area confirmation
2. Build placement
3. Factory/Lab queue action
4. Tactical radial action
5. Disassemble `LB+A`
6. Normal A single/double/hold selection

X priority:

1. Active tactical point/area confirmation
2. Build placement
3. Factory/Lab dequeue action
4. Tactical state reverse cycle
5. Disassemble pending X reclaim/Move/hold
6. Normal Smart X

B priority:

1. Active target cancellation
2. Build cancellation
3. Radial close
4. Disassemble selection clear/target cancel
5. Disassemble double-B exit when already clear
6. Normal clear selection

D-pad priority:

1. Radial/modal navigation
2. Build controls
3. Back/View bindings
4. LB+D-pad Down idle same-type selection
5. Idle previous/next

