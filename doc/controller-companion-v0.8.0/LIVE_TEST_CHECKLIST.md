# v0.8.0 v0.6 Input Restore Live Checklist

Automated validation does not establish gameplay success. BAR is deliberately left closed after deployment.

## Tactical and areas

- [ ] LB shortcuts issue Fight, Patrol, and Attack once at the current cursor.
- [ ] Tactical point selection waits for release; fresh A and fresh X each confirm; B cancels.
- [ ] Area Mex A→A, A→X, X→A, and X→X each produce one preview and one dispatch.
- [ ] Smart Area Reclaim and Tactical Reclaim pass the same four confirmation combinations.
- [ ] Disassemble same-type radius and enemy anchor pass all four combinations.
- [ ] Releasing A/X never confirms; B cancels; RT preserves queue semantics.
- [ ] Direct LB+A Disassemble reclaim, constructor restoration, timeout, and double-B remain correct.

## Selection and idle

- [ ] Repeated single A taps always select one exact hovered unit.
- [ ] Intentional double A expands only to visible/on-screen locally owned same-type units.
- [ ] Hold A opens the normal brush and RT+A toggles one exact unit.
- [ ] D-pad Right/Left follow the current ZZZ order, wrap, and recover after a unit becomes busy/dies.
- [ ] LB+D-pad Down selects only current idle units matching the remembered type.

## UI and companion

- [ ] Self Destruct appears under Utility for eligible mobile units and structures, but requires the protected chord/hold.
- [ ] One-category Build/Factory pages show a large heading; mixed pages show sector labels only.
- [ ] PAGE n/N remains inside the lower center circle without overlapping details at all radial scales.
- [ ] Native cells, selected border, quantities, groups, hints, panels, profiles, themes, favorites, and Legacy fallback remain intact.
- [ ] Bridge header is compact ASCII, connection colors are sensible, tracked PID appears, and Ctrl+C exits cleanly.

Record BAR build, map, unit selections, controller model, pass/fail notes, screenshots, and `infolog.txt` excerpts before making any gameplay-success claim.
