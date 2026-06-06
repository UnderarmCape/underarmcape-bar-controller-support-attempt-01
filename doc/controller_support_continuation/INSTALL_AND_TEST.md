# Installation and Manual Testing

## Installation Path
Copy the widgets into the following directory:
`C:\Users\kaili\AppData\Local\Programs\Beyond-All-Reason\data\games\BAR.sdd\luaui\Widgets`

## Manual Install Instructions
1. Install v0.4.3 AIO / controller-enabled engine first.
2. Download v0.4.5 incremental Lua widgets.
3. Copy the included `luaui\Widgets\*.lua` files into the live `BAR.sdd` folder path listed above.
4. Overwrite matching files.
5. Launch BAR.
6. Test in **Singleplayer -> Beyond All Reason Dev**.

## Manual Test Checklist
- [ ] **Widget loads**: Widget appears without console errors.
- [ ] **No Lua errors**: Console remains clean during runtime.
- [ ] **Command Toast appears**: UI toasts show action confirmations (e.g. MOVE, LOAD UNIT).
- [ ] **Builder Repair Area**: LB + A starts Repair Area auto-anchored radial.
- [ ] **Builder Reclaim Area**: LB + X starts Reclaim Area auto-anchored radial.
- [ ] **Air transport load/unload**:
  - X tap loads units on allied, moves on ground.
  - LB + X loads unit; fails safely on empty ground.
  - LB + A unloads cargo unit; fails safely if empty.
  - LB + Hold X / LB + Hold A activates auto-anchored area load/unload radials.
- [ ] **Build placement slow/full pan**: Toggle works during placement.
- [ ] **Tactical radial**: Menu opens and selects target category.
- [ ] **Build/factory B/X behavior**: Items are correctly added and removed from the queue.
- [ ] **Area Mex**: Exposes and issue Area Mex correctly.
- [ ] **Repair Area / Reclaim Area**: Previews and overlays draw correctly.
