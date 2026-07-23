# v0.8.4 Idle Pool Expansion

Normal D-pad Left/Right cycles the primary idle pool: builders, factories, labs, and non-combat infrastructure. LB+D-pad Left/Right cycles the secondary idle pool: idle mobile combat/support units that are not builders and are not transported.

The current pool is remembered. LB+D-pad Down selects all idle units of the currently focused UnitDef from the remembered pool, so build idle selection and mobile idle selection do not collapse into each other.

The implementation remains controller-owned and uses direct unit enumeration, selection, and camera focus. It does not invoke vanilla mouse clicks or the Idle Builders widget click wrappers.
