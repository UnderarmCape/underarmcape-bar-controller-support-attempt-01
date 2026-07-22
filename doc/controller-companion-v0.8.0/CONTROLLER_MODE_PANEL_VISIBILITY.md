# Controller-mode panel visibility

Native Experimental controller mode hides the Build Menu and Order Menu panels
after a 0.15-second enter hysteresis. Mouse mode restores them after a
0.35-second exit hysteresis. `nativePanelsDebugVisible` can keep them visible
for diagnosis.

Hiding is rendering-only: both widgets continue refreshing descriptors, cells,
queue state, focus, and controller APIs. Their guishader display lists and mouse
hit ownership are removed while hidden. Existing widget enablement and order
are unchanged; Build Menu remains above Grid Menu in `BYAR.lua`.
