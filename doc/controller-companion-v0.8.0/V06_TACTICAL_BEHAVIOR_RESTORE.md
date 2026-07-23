# v0.6 Tactical Behavior Restore

The behavioral source is annotated tag `controller-support-v0.6.1-radial-typography`, commit `d345fd1ee790e4ff392f020b82d8aa3b52db0edf`. Current native descriptors and renderers remain the data/presentation source; the camera widget again owns controller target input.

Immediate LB Fight, Patrol, Attack, Guard, and Move shortcuts sample the controller cursor and issue once. Tactical Radial point commands close the radial, consume the selection edge, wait for A/X neutrality, and accept one fresh A or X. Area commands use fresh A/X to anchor, release to arm, cursor movement to size, and another fresh A/X to confirm. B cancels every staged command.

`controllerBeginTarget`, `controllerTargetInput`, and the hybrid native target poll are inactive. Their prior implementation is recoverable from the pre-restore commit documented in `PRE_V06_RESTORE_RECOVERY.md`.
