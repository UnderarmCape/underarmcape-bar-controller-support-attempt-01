# v0.8.0 Native Input and Disassemble Live Checklist

**EXPERIMENTAL — INPUT STATE, FACTORY SHORTCUT, AND VANILLA DISASSEMBLE TEST**

## Tactical area command

1. Select an area command.
2. Move cursor to center.
3. Press A to anchor.
4. Release A.
5. Move cursor.
6. Confirm center remains fixed and only radius changes.
7. Press A to confirm.
8. Repeat A anchor → X confirm.
9. Repeat X anchor → A confirm.
10. Press B during resize and verify cancellation.

## Build placement

11. Enter placement with one constructor.
12. Press B once.
13. Confirm placement closes immediately.
14. Confirm constructor remains selected.
15. Repeat with multiple constructors.
16. Repeat in Grid mode.
17. Reenter and confirm Single mode.

## Factory/Lab Radial

18. A adds one.
19. X removes one.
20. RT+A adds five.
21. RT+X removes five.
22. Remove-five at low count clamps to zero.
23. Hold LB+RB to toggle Queue Mode.
24. Confirm radial stays open.
25. Confirm toast and native state match.

## Move State

26. Select units in mixed Move States.
27. Hold LB and tap RB.
28. Confirm all capable units converge to the next state.
29. Confirm toast.
30. Confirm unsupported units are unaffected.

## Disassemble

31. Attempt entry with combat units only; verify rejection.
32. Enter with constructor plus combat units.
33. Hold A to area-select friendly targets.
34. Confirm real vanilla selection outlines.
35. Confirm cached constructors are not included.
36. Hold LB and tap A.
37. Confirm every selected target receives reclaim.
38. Confirm constructors become selected again.
39. Hold LB+A over one target.
40. Resize same-type reclaim radius.
41. Press A or X to confirm.
42. Verify only matching target types are reclaimed.
43. Press B during another attempt and verify cancellation.
44. Confirm Disassemble remains active.

## General

45. Verify radial compaction remains correct.
46. Verify vanilla blue focus stays synchronized.
47. Test Legacy fallback.
48. Check `infolog.txt`.
49. Watch for duplicate commands, stuck inputs, or frame-time spikes.
