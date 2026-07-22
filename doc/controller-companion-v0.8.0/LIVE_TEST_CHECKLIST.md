# v0.8.0 Native Input Polish Live Checklist

**EXPERIMENTAL — AREA CONFIRMATION, DISASSEMBLE, AND HINT POLISH TEST**

## Tactical area command

1. Select an area command.
2. Press A to anchor.
3. Release A.
4. Resize.
5. Press A to confirm.
6. Repeat A anchor → X confirm.
7. Repeat X anchor → A confirm.
8. Repeat X anchor → X confirm.
9. Confirm exactly one command each time.
10. Cancel with B.

## Build Radial eligibility

11. Clear selection and press RB; nothing should open.
12. Select combat units and press RB; nothing should open.
13. Select a factory/lab and verify only Factory/Lab Radial behavior.
14. Select a constructor and confirm Build Radial opens.
15. Change selection and verify no stale radial model opens.

## Move State and chord ownership

16. Hold LB.
17. Tap RB repeatedly without releasing LB.
18. Confirm every tap advances Move State.
19. Confirm unsupported selection shows no toast.
20. Hold LB+RB in Factory Radial and confirm Queue Mode.
21. Confirm Disassemble does not activate for factory/lab.
22. Long-hold with combat units only; confirm silent no-op.
23. Long-hold with constructor; confirm Disassemble.

## Disassemble target selection

24. Hold A and compare circle behavior with normal area selection.
25. Confirm Disassemble circle is green.
26. Confirm circle does not use tactical fixed-anchor behavior.
27. Select targets with Hold A.
28. Use RT+Hold A to add more targets.
29. Use RT+A to add/remove individual targets.
30. Confirm vanilla outlines.
31. Confirm cached constructors remain excluded.

## Disassemble timer and exit

32. Enter Disassemble and perform no reclaim.
33. Confirm auto-exit after 30 seconds.
34. Enter again and issue reclaim.
35. Confirm timer resets.
36. Double-tap B while idle and confirm exit.
37. Start a sub-operation, press B to cancel, then press B again to exit.

## Reclaim ordering

38. Select a 3×3 target grid.
39. Issue selected-target reclaim.
40. Confirm constructors begin with nearby targets.
41. Confirm movement progresses locally instead of star-shaped jumping.
42. Repeat with multiple constructors.
43. Test same-type area reclaim.
44. Confirm native-like ordering.

## Hints

45. Confirm hints are significantly larger and more readable.
46. Open Controller Bindings UI.
47. Adjust Hint Overall Scale.
48. Adjust text and glyph scales.
49. Adjust spacing.
50. Reset hint appearance.
51. Confirm settings persist.
52. Compare Xbox/PlayStation or restored glyph styles.

## General

53. Recheck build placement B cancellation.
54. Recheck factory +1/−1/+5/−5.
55. Recheck radial compaction.
56. Recheck blue native focus synchronization.
57. Test Legacy fallback.
58. Check `infolog.txt`.
59. Watch for duplicate commands or frame-time spikes.
