# v0.8.0 Native Hybrid Targeting Live Checklist

**EXPERIMENTAL — NATIVE CONTROLLER TARGETING AND COMPACT RADIAL TEST**

1. Select Guard from Tactical Radial and place it with A.
2. Repeat using X.
3. Test Repair, Reclaim, Attack, Capture, and Set Target.
4. Select an area command.
5. Press A to anchor.
6. Release A and confirm nothing issues.
7. Move the cursor to resize the anchored radius.
8. Press A again and confirm exactly one operation.
9. Repeat using X, then mixed A/X presses.
10. Press B during point and area targeting; confirm selection remains and no order issues.
11. Enter build placement with one constructor, several constructors, a commander, and a construction turret where valid.
12. Place several queued and non-queued buildings; verify A and X both keep placement active.
13. Press B after valid, invalid, shoreline, and water previews; confirm constructors remain selected, Grid resets, and controls return immediately after B release.
14. Press X afterward and confirm normal Smart X works on the next clean press.
15. Test Build Radial categories with several constructors.
16. Confirm no empty categories, empty pages, or trailing pages.
17. Confirm absent commands create no holes before later items.
18. Confirm unaffordable and disabled but present commands remain visible.
19. Test multiple factories and labs; queue with A and dequeue with X.
20. Confirm vanilla cell 1 is top radial slot 1 and later present cells are consecutive.
21. Move both stick and mouse focus; confirm radial focus and the blue vanilla focus stroke match without flicker.
22. Verify Fire State, Move State, Visible/Cloak, Stop, Disassemble, LB+B, and RT+A; switch to Legacy fallback and back while preserving selection.
23. Check `infolog.txt` for Lua errors, invalid target paths, or focus mismatch.
24. Watch for duplicate orders, stuck A/X/B ownership, repeated resize/layout calls, or frame-time spikes.

Report a mismatch with the selected builder/factory, command name and type, target kind, radial category/page/slot, blue-focused vanilla cell, and relevant `infolog.txt` lines.
