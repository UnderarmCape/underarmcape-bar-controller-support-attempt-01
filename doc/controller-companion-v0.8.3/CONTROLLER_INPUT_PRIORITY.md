# Controller Input Priority

v0.8.3 keeps modal ownership explicit so controller actions do not steal one another.

- Active build placement and Tactical targeting own A/X before normal selection or Smart X.
- Hold-X movement owns X until release confirms the hold did not trigger.
- Disassemble resolves L3+R3, LB+B, LB+A, X, then B.
- Self Destruct only owns L3+R3 after the protected Tactical action is armed and Back/View is held.
- Hint and binding metadata no longer exposes a Y repair modifier.

Use the source harnesses under `tools/controller-ui-tests` before shipping a controller-input change.
