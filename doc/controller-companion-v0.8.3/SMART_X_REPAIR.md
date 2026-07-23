# Smart X Repair

v0.8.3 makes normal X the direct repair entry point when the reticle is over a valid damaged friendly unit.

- Tap X over a damaged own or allied unit: issue Repair once through the normal selected-unit order path.
- Hold X: keep the existing Move/path behavior and do not issue Repair while the hold is developing.
- Invalid, healthy, dead, enemy, or empty targets fall through to the normal Smart X/default command resolver.
- Y is not a repair modifier in this release. Holding Y must not change Smart X behavior.

Manual check: select a constructor, point at a damaged friendly structure and tap X. Then repeat with a healthy friendly target, enemy wreck, empty ground, and a Hold-X move path.
