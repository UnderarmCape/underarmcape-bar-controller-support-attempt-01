# Live Test Checklist

Run these with BAR closed before deployment and with BAR open only for manual gameplay validation.

- Verify no BAR, Spring, Recoil, bridge, launcher, updater, installer, or restore process is running before install/deploy.
- Run Lua parse checks and the v0.8.3 source harness.
- Validate shipping defaults against the manifest.
- Build and validate the public package inventory.
- Deploy through the manifest-driven updater and validate the generated recovery backup.
- In game, test Smart X repair, RB+A insertion, Disassemble chords, double-tap same-target selection, Tactical Wait/Move State, and protected Self Destruct.

Automated validation proves package, source, and rollback integrity. It does not prove live gameplay success unless the manual BAR checks are performed.
