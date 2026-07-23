# BAR Controller Support v0.8.4

Release tag: `controller-support-v0.8.4-general-insert-disassemble-idle`

Package: `BAR_Controller_Support_v0.8.4_GENERAL_INSERT_DISASSEMBLE_IDLE_EXPANSION.zip`

- General Insert is restored for active command confirmations outside Build and Factory, using RB+A and RB+X. Y insertion remains removed.
- RT+RB is a hard suppression chord: it consumes the conflict, closes controller-owned selection radial state, and waits for neutral before rearming.
- Smart X now prioritizes damaged friendly Repair, then enemy unit Reclaim when a selected reclaimer exists, then the existing Smart X path. Hold-X movement is unchanged.
- Idle cycling now separates build/infrastructure units from idle mobile combat/support units, with LB+D-pad Down selecting all idle units of the remembered pool/type.
- Disassemble keeps friendly targets in vanilla Spring selection and enemy targets in controller-owned marked state, allowing mixed selected collections without selecting hostile units.
- Disassemble LB+A tap reclaims the full selected mixed collection, falling back to the one-shot reticle target only when the collection is empty.
- Disassemble LB+Hold-A uses the controller area circle, captures UnitDef identity, resizes after release-to-neutral, confirms with A/X, cancels with B, and remains in Disassemble.
- B clears active Disassemble target state before double-B exit can arm. LB+B Stop and L3+R3 Clear Queue keep their higher-priority behavior.
- Self Destruct returns to the direct custom protected flow while retaining the red/native-style Tactical button presentation.

Validation target: 113 v0.8.4 source checks, retained v0.8.1-v0.8.3 recovery harnesses, release package validation, deployment validation, rollback validation, and GitHub Latest publication verification.
