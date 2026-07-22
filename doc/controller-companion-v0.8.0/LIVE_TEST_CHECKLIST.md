# v0.8.0 Experimental live test checklist

Run against `Beyond All Reason test-30735-bf9c7bf` with Native Experimental selected. These are manual checks; automated validation is not a claim of live gameplay success.

## Version/lifecycle

1. Launch bridge and confirm `BAR Controller Bridge v0.8.0 Experimental`.
2. Launch a game session.
3. Exit Spring/Recoil.
4. Confirm session companion and bridge close cleanly.

## A selection

5. Repeatedly select individual same-type units with A.
6. Confirm every tap selects only the hovered unit.
7. Perform at least 50–100 repeated selections.
8. Verify Hold-A area selection.
9. Verify RT+A additive selection.

## Tactical immediate commands

10. Test LB immediate Attack.
11. Test LB immediate Patrol.
12. Test LB immediate Fight.
13. Confirm commands issue at the current cursor.
14. Confirm one order each.

## Tactical Radial

15. Choose a point command.
16. Confirm no anchor appears during radial selection.
17. Press a fresh A to place.
18. Repeat with X.
19. Test B cancellation.
20. Test Area Mex four A/X combinations.
21. Test Smart Reclaim four combinations.
22. Test Disassemble radius four combinations.

## State cycling

23. Focus Move State and press A repeatedly.
24. Press X repeatedly to reverse.
25. Repeat with Fire State.
26. Confirm no sub-radial opens.

## Constructor radial

27. Confirm Economy, Build, Utility, and Combat items exist.
28. Confirm factories/labs/construction turrets appear in Build.
29. Inspect sparse mixed pages.
30. Confirm colored sectors and labels.
31. Confirm Economy and Combat may share clearly.
32. Traverse all pages with RB/LB.

## Factory radial

33. Confirm order Constructors→Utility→Combat.
34. Confirm scouts/transports/support units are grouped in Utility.
35. Confirm combat units are grouped together.
36. Confirm mixed sectors and labels.
37. Recheck A/X/RT quantity controls.

## Native cells

38. Compare radial items to vanilla Build Menu cells.
39. Confirm icons, costs, badges, queue counts, and disabled states match.
40. Confirm selected-border scale still works.

## Idle units

41. D-pad Right through the live ZZZ entries.
42. D-pad Left backward.
43. Confirm camera focus.
44. Create several idle units of one type.
45. Focus one with D-pad.
46. Press LB+D-pad Down.
47. Confirm all currently idle units of that type are selected.
48. Confirm busy/non-idle units are excluded.

## General

49. Recheck Smart X.
50. Recheck Hold-X drag Move.
51. Recheck Distributed Grid.
52. Recheck Build cancellation.
53. Recheck groups.
54. Recheck hint stability.
55. Recheck hidden panels.
56. Test Legacy fallback.
57. Check `infolog.txt`.
58. Watch for duplicate orders and frame-time spikes.
