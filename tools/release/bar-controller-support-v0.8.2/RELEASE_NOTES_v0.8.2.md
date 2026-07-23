# BAR Controller Support v0.8.2

Release tag: `controller-support-v0.8.2-tactical-insert-idle-repair`

## Fixed

- Restored Y+A and Y+X Repair over valid allied repair targets while preserving Smart X fallback.
- Kept Tactical Hold Position/Move State and Wait open after activation, with refreshed state labels.
- Restored LT+A factory Insert Queue and RB+A front insertion for compatible active orders.
- Removed Back/View + D-pad Down reclaim while preserving the shared one-shot reclaim helper.
- Repaired Disassemble B target clearing, L3+R3 Clear Queue, and LB+B Stop.
- Removed cursor-overlap dependency from double-tap A same-type selection.
- Restored exact v0.6 ordinary idle navigation from own-team idle candidates.
- Routed Tactical Self Destruct through the protected Back/View + L3 + R3 hold flow and rendered it with the shared red danger button style.

## Notes

BAR was not launched by the package tooling. Manual gameplay verification is still required for live controller feel, but automated source, package, deployment, and rollback validation cover the repaired paths.
