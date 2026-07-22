# Controller shoulder arbitration

The shoulder state machine uses `rbTapMaxSeconds` (default 0.22) and
`rbChordGraceSeconds` (default 0.18).

- RB press starts a pending solo cycle. Release within the tap window opens the
  eligible Build or Factory radial; holding RB alone has no action.
- When LB is already down, each distinct RB press/release cycles Move State
  once. Keeping LB held permits repeated RB taps.
- When RB is first, LB must join inside the grace window. A later LB press is
  blocked until RB releases. Repeated LB taps while RB stays held cannot cycle.
- A recognized chord can fire Factory Queue Mode or enable/disable Disassemble
  after the existing long-hold threshold.
- Active-placement LB+RB+RT consumes the cycle before shoulder actions run.

Every terminal path re-arms on the required RB release, preventing a single
physical cycle from creating two actions.
