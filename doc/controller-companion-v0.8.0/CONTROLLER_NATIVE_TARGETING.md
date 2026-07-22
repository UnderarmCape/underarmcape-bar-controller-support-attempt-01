# Controller native targeting

Status: **EXPERIMENTAL — SMART X, RADIAL ROUTING, ENEMY DISASSEMBLE, AND AREA CONFIRMATION TEST**

Order Menu is the authoritative broker boundary. A retained session contains
the command descriptor/ID, registered owner identity and token, phase, anchor,
current endpoint/radius, confirmation arm, owner confirm/cancel callbacks, and
final-dispatch state. Engine active-command clearing, radial closure, panel
visual suppression, and input-mode transitions do not replace an already
validated owner session.

The camera checks this broker before normal A selection, Smart X, and
`Spring.GetActiveCommand`. First A/X anchors. After both buttons are observed
neutral, the broker arms; the next fresh A or X edge invokes the same registered
owner's confirm callback. Release never confirms. B calls the owner's cancel.
BAR's native command eligibility and engine rejection remain authoritative.

The dispatch boundary is exactly once:

1. Invoke one owner confirm callback.
2. Attempt `widgetHandler:CommandNotify` once.
3. If handled, close without a direct order.
4. If unhandled, attempt one `Spring.GiveOrder`/`CMD.INSERT` fallback.
5. Mark final dispatch and close, preventing Smart X or another handler from
   issuing again.

With Controller Debug enabled, Order Menu keeps transition-only diagnostics:
`SESSION CREATED`, `OWNER`, `ANCHORED`, `BUTTONS NEUTRAL`, `CONFIRM ARMED`,
`A/X CONFIRM RECEIVED`, `OWNER CONFIRM CALLED`, `COMMAND_NOTIFY HANDLED` or
`GIVE_ORDER FALLBACK`, and `SESSION CLOSED`. The camera draws the last four
rows. A debug self-check reports owner count, Area Mex and Smart Area Reclaim
registration, broker availability, and dispatcher connectivity. Nothing logs
per frame.

The same deployed source order and owner registration path are exercised by
the regression harness. The final gameplay proof remains the 47-step live
checklist; automation cannot substitute for pressing the second button in BAR.
