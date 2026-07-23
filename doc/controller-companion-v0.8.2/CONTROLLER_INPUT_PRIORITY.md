# Controller Input Priority

Primary repairs:

- A: modal confirmations and factory actions remain first; Y+A Repair runs before normal A selection only when a valid repair target exists.
- X: modal confirmations and factory dequeue remain first; Tactical X can reverse state cycles; Y+X repairs valid targets and otherwise falls through to Smart X.
- B: LB+B Stop outranks Disassemble clearing; Disassemble target clear outranks double-B exit.
- Stick clicks: L3+R3 Clear Queue outranks independent queue-removal clicks inside Disassemble.
- Shoulders/triggers: LT+A Insert Queue applies only in factory radials; RB+A Insert Order applies only while an insert-compatible active command or placement is awaiting confirmation.

No repaired branch should execute two controller actions for one edge.
