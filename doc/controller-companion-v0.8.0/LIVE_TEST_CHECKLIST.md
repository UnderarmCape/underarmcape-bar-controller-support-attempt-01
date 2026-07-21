# v0.8.0 native integration live checklist

Keep BAR closed until ready to perform this checklist. This package is experimental and may require a rebase after BAR updates.

1. Start a skirmish and confirm normal A selection uses BAR's ordinary selected-unit outlines.
2. Use RT+A to add and remove friendly mobile units and structures without changing the rest of the selection.
3. Select reclaim-capable constructors and hold LB+RB for the new 0.33-second default to enter Disassemble Mode.
4. Open Controller Bindings, change **Disassemble Toggle Hold Duration** within 0.15–1.50 seconds, exit/reopen the panel, and retest entry and exit.
5. Aim at a friendly unit/structure and tap LB+A for single native reclaim.
6. Hold LB+A on a friendly unit/structure, move the reticle to set the radius, and release A for native same-type area reclaim.
7. Compare the reclaim command cursor/radius and resulting orders with mouse/keyboard BAR.
8. During targeting press B to cancel; with no target active press B to clear the vanilla selection. Confirm Disassemble remains active.
9. During targeting press X over ground; confirm targeting cancels, Move is issued, and Disassemble remains active.
10. Press LB+B; confirm native Stop reaches the actual selected units and Disassemble remains active.
11. Open the tactical layer and test Visible/Cloak on a capable unit.
12. Cycle Fire State forward and backward and compare the order panel state.
13. Cycle Hold Position, Maneuver, and Roam and compare the order panel state.
14. Test Repeat, On/Off, Priority, factory, transport, and wait controls only where the native panel advertises them.
15. Select a builder/factory, open the native build UI, navigate with D-pad, activate with A, and decrement a factory queue with X.
16. Move back to mouse/keyboard and confirm the standard build grid returns after the input hysteresis delay without flicker.
17. In Bindings UI compare Auto, Xbox, and PlayStation glyph styles; unplug/reconnect if testing Auto detection.
18. Confirm the five D-pad glyphs look exactly like v0.7.0.
19. Inspect `infolog.txt` for Lua errors, widget removal, duplicate orders, and compatibility warnings; observe frame-time while input is idle and while menus are open.
20. Switch **Native BAR UI Integration** to **Legacy Controller UI** and smoke-test v0.7 selection, reclaim, tactical, and build paths without double rendering.

If native widgets disappear after a BAR update, close BAR and restore immediately. Do not use the unknown-base override as a routine fix.
