# v0.8.0 Native Hybrid Live Checklist

Experimental — native panels and blue focus remain visible for validation.

1. Open Build Radial with several constructors; verify v0.7 cards, categories, center description/costs, and pages.
2. Move the stick and mouse between items; verify radial highlight and blue vanilla focus agree.
3. Verify familiar buildings retain positions when switching constructors, including unsupported-item holes.
4. Open several labs/factories; verify no builder categories and vanilla cell 1 at top slot 1.
5. Queue with A and dequeue with X; verify vanilla queue counts update.
6. Open Tactical; use D-pad Up/Down for Utility/Tactical and stick for items.
7. Test Visible/Cloak and other binary states.
8. Open Fire State and Move State sub-radials; confirm the exact live states.
9. Test Stop, Guard, Repair, Reclaim, Restore, Area Mex, and supported target commands.
10. Enter build placement; verify Single every time.
11. Hold LB for Grid; release LB and verify immediate Single.
12. Exit/reopen and change build item; verify Grid never remains latched.
13. Test X Quick Place, A normal placement, B cancel, rotation, spacing, water/shoreline, and queue modifiers.
14. Test Selection, area selection, visible filter, control groups, and Disassemble/reclaim.
15. Switch to Legacy Controller UI and back; verify radials close, placement resets, and selection remains.
16. Check `infolog.txt` for Lua errors, focus mismatches, or duplicate command activation; watch frame time.

Report a mismatch with selected builder/factory, command name, radial slot/page/category, and the blue-focused vanilla cell.
