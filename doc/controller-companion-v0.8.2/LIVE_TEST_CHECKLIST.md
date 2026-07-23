# Live Test Checklist

Release: `controller-support-v0.8.2-tactical-insert-idle-repair`

Manual gameplay checks:

1. Y+A and Y+X repair damaged allied structures and mobile units.
2. Invalid Y+X still runs Smart X.
3. Tactical Hold Position cycles forward/back and remains open.
4. Tactical Wait toggles once and remains open.
5. Factory LT+A inserts one focused unit at queue front and shows INSERT.
6. RB+A fronts a compatible build/order and shows INSERT.
7. Back/View + D-pad Down does not reclaim.
8. Disassemble X reclaim, ground Move, Hold-X path Move, B clear, L3+R3 Clear Queue, and LB+B Stop all work.
9. Double-tap A selects spread-out visible owned same-type aircraft, bots, vehicles, ships, constructors, and structures without overlap.
10. D-pad Left/Right cycles idle units; LB+D-pad Down selects the current idle type bucket.
11. Tactical Self Destruct shows the red danger button and completes only after the protected Back/View + L3 + R3 hold.
12. Recovery Mode shows v0.8.2 as Latest/Installed and keeps v0.8.1 available.

BAR is not launched by release tooling; do not claim manual gameplay success without running this checklist.
