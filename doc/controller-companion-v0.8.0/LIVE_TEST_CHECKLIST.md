# v0.8.0 native regression-repair live checklist

**EXPERIMENTAL — SMART X, RADIAL ROUTING, ENEMY DISASSEMBLE, AND AREA CONFIRMATION TEST**

Run against `Beyond All Reason test-30735-bf9c7bf`. Enable Native Experimental,
leave Legacy available, and enable Controller Debug only when collecting the
transition strip.

## Smart X

1. Test normal Smart X tap behavior against the pre-unification behavior.
2. Test Hold-X drag Move.
3. Test ground-constructor Repair.
4. Test air-constructor Repair.
5. Test constructor Reclaim on an enemy unit.
6. Test constructor Reclaim on an enemy structure.
7. Confirm X does not Move over a valid Repair/Reclaim target.

## Build and Factory paging

8. Tap RB to open the Build Radial.
9. Tap RB to move to the next page.
10. Tap LB to move to the previous page.
11. Repeat paging with a Factory/Lab Radial.
12. Confirm a one-page model safely remains on its page.

## Tactical toggle

13. Hold Back/View and press RB.
14. Confirm the Tactical Radial opens.
15. Repeat the chord and confirm it closes.
16. Confirm the chord never opens Build/Factory.
17. Confirm RB cannot open Build/Factory while Tactical is open.

## Idle units

18. Use D-pad Left in normal gameplay.
19. Use D-pad Right in normal gameplay.
20. Confirm vanilla Idle Builders ordering.
21. Confirm vanilla selection and camera focus.
22. Confirm the vanilla idle icon highlight and sound.

## Enemy Disassemble

23. X-reclaim an enemy unit.
24. X-reclaim an enemy structure.
25. LB+A tap an enemy target.
26. LB+A hold over an enemy target.
27. Confirm same-type area Reclaim includes valid enemy matches.
28. Brush enemy targets with Hold A.
29. Add enemy targets with RT+Hold A.
30. Confirm owned constructors touched by the brush join the reclaimer set and are not targets.

## Area commands

31. Open Area Mex or another area command through an LB Tactical Radial.
32. Test A anchor → A confirm.
33. Test A anchor → X confirm.
34. Test X anchor → A confirm.
35. Test X anchor → X confirm.
36. Confirm exactly one command appears for each test.
37. Confirm B cancels without issuing.
38. If a test fails, enable Controller Debug and record the last transition shown.

## General regression pass

39. Recheck Distributed Grid.
40. Recheck one-B build cancellation and constructor selection preservation.
41. Recheck Factory +1/−1/+5/−5 quantities.
42. Recheck vanilla control groups.
43. Recheck native panels hide in controller mode and return in mouse mode.
44. Recheck stable hints without passive-hover churn.
45. Switch to Legacy fallback and back to Native Experimental.
46. Inspect `infolog.txt` for Lua errors or removed widgets.
47. Watch for duplicate orders or frame-time spikes.
