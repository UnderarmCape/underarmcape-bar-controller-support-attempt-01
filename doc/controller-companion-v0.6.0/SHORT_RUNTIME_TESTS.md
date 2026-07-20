# Short BAR runtime checks

The original v0.6 foundation already passed its live BAR matrix. After copying the three development widgets and companion tools, run only these additions:

1. Move and resize the `UI Layout` launcher; save, reload LuaUI, change resolution, and confirm it remains clamped and persistent.
2. Try hint context/presentation modes, layer toggles, 2–8-line wrapping, shrink, truncate, columns, expansion, and optional marquee.
3. Confirm D-pad Down shows `Select Commander`, then selects/focuses Commander.
4. In Actions, reorder/hide/restore one action and one category; verify the live overlay changes and undo restores it.
5. Move hot slots; try horizontal, vertical, grid, visible count, empty hiding, sizes, labels, counts, AUTO, and theme override without changing group behavior.
6. Exercise mouse wheel, Shift/Ctrl modifiers, held +/- acceleration, arrows, Page Up/Down, Home/End, Tab/Shift+Tab, search, and direct text editing.
7. Test multi-step undo/redo, explicit Save, an interrupted unsaved edit, recovery, discard/reset, and profile-import backup.
8. Enable Developer Authoring Mode, toggle one E enforcement marker, and Save Draft. Confirm no publish request appears from ordinary Save or recovery.
9. Run publisher `validate`, then `dry-run` against a disposable local repository and inspect the one two-file commit. Do not live-publish.
10. Point the test harness at a newer fixture and confirm startup imports it, preserves the old `*.previous.json` pair, and writes manifest last.
11. Repeat with the fixture offline/malformed/hash-invalid and confirm startup remains bounded and the valid cache stays active.
12. Confirm release discovery only reports availability; `update` requires download approval and separate apply approval.
13. Recheck build placement, radials, Smart X, Mouse Mode, Back+Start timing, groups, bindings, companion UDP, and the unchanged full-screen Bindings window.

Do not launch a live publish, push the source branch, create a release, or build a public package during this pass.
