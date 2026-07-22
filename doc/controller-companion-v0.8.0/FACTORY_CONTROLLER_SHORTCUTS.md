# Factory Controller Shortcuts

Status: **EXPERIMENTAL — INPUT STATE, FACTORY SHORTCUT, AND VANILLA DISASSEMBLE TEST**

## Queue quantities

When a Factory/Lab Build Radial owns input, A performs the authoritative vanilla build-cell left click and X performs the authoritative right click. RT supplies vanilla Shift quantity:

- A: add 1
- X: remove 1
- RT+A: add 5
- RT+X: remove 5

The patched Build Menu resolves the live command cell and calls `Spring.SetActiveCommand` with the real descriptor and mouse/modifier form. BAR/Recoil therefore owns queue validity, availability, Queue Mode semantics, count display, and zero clamping. No controller-side queue count is fabricated. Each action originates from one pressed edge and refreshes native queue metadata without rebuilding unrelated radial pages.

## Central LB/RB chord

One pure state machine owns LB-held plus RB tap/hold input. It starts on the RB press while LB is held, latches the factory context, and waits for RB release or the configured hold threshold (shipped as 0.33 seconds).

- RB released before the threshold: cycle Move State.
- Held through the threshold inside a Factory/Lab Radial: toggle the real `factoryqueuemode` state descriptor, keep the radial open, and show `Queue Mode Enabled` or `Queue Mode Disabled`.
- Held through the threshold outside a Factory/Lab Radial: enter or exit Disassemble Mode.

A long action suppresses the short action. Both buttons must be released before another chord can arm. Because this owner runs before Build Menu navigation, LB/RB page actions cannot leak from the same cycle.

## Move State

The first selected unit exposing the native Move State descriptor supplies the current state and state count. The next descriptor value is sent to all selected units that expose a compatible Move State descriptor; unsupported units are skipped. Selection is untouched. Toasts use the native three-state meaning: `Move State: Hold Position`, `Move State: Maneuver`, or `Move State: Roam`.

Legacy Controller UI remains available. Native and Legacy handlers are mutually exclusive and cannot toggle state twice.

