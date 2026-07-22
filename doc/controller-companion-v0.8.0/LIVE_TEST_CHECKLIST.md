# v0.8.0 hybrid area / idle repair live checklist

**EXPERIMENTAL — HYBRID AREA TARGETING, GLOBAL RADIAL PAGING, AND VANILLA IDLE CONTROL TEST**

Run against `Beyond All Reason test-30735-bf9c7bf` with Native Experimental enabled and Legacy available.

## Area commands

1. Open Area Mex.
2. A anchor → A confirm.
3. A anchor → X confirm.
4. X anchor → A confirm.
5. X anchor → X confirm.
6. Confirm exactly one Area Mex batch.
7. Repeat with Smart Area Reclaim.
8. Repeat with another circular area command.
9. Test a front/rectangle command if available.
10. Confirm B cancels.

## Build Radial traversal

11. Open a constructor with Economy, Combat, and Utility commands.
12. RB through every Economy page.
13. Confirm next RB enters Combat.
14. Continue into Utility.
15. Confirm wrap to Economy.
16. Use LB to traverse the exact reverse order.
17. Confirm first valid item is focused after category changes.

## Idle Builders

18. Create multiple idle builders.
19. D-pad Right cycles through vanilla ZZZ entries.
20. D-pad Left cycles backward.
21. Confirm vanilla camera movement and highlight.
22. Use the mouse on the ZZZ widget and confirm controller remembers that entry.
23. With multiple idle units of the same type, press LB+D-pad Down.
24. Confirm all currently idle units of that type are selected.
25. Confirm non-idle units of that type are not selected.

## Enemy Disassemble

26. LB+A tap enemy target remains functional.
27. LB+A hold over enemy unit.
28. Resize and confirm with A.
29. Repeat confirming with X.
30. Repeat with enemy structure.
31. Confirm same-type enemy reclaim operates once.
32. Confirm Disassemble remains active.

## General

33. Recheck Smart X.
34. Recheck Hold-X drag Move.
35. Recheck Tactical toggle.
36. Recheck Distributed Grid.
37. Recheck factory quantities.
38. Recheck control groups.
39. Recheck stable hints.
40. Recheck hidden panels.
41. Test Legacy fallback.
42. Check `infolog.txt`.
43. Watch for duplicate commands or frame-time spikes.
