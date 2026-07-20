# Controller UI Layout Editor validation

## Editor behavior

- Open by clicking `UI Layout`, using `/luaui bar_controller_ui`, or holding Back/View + Start/Menu for 1.5 seconds.
- Drag the header to move; drag the lower-right handle to resize.
- Use General, Hints, Actions, Hot Slots, Launchers, Radials, Status, Other, Theme, Authoring, and Recovery tabs with Basic/Advanced/All/Favorites/Recent/Modified filters.
- Changes preview immediately; explicit Save promotes them. Reset Section and Reset All restore validated defaults.
- Position/size and all component values migrate into Controller UI Layout schema 3. Explicit Save promotes a preview to personal settings; dirty recovery remains separate.
- `ViewResize` recomputes automatic scale and clamps the editor and Bindings launcher on-screen.
- The full Controller Bindings UI window has no new move, resize, position, or dimension code.

## Shortcut state machine

`BACK_START_EDITOR_HOLD_SECONDS = 1.5` is a named elapsed-time threshold.

- Both pressed: start one chord cycle; Mouse Mode does not toggle yet.
- Either released before 1.5 seconds: toggle Mouse Mode once and lock the cycle.
- Held through 1.5 seconds: toggle the layout editor once, do not change Mouse Mode, and lock the cycle.
- Continued hold: no repeat.
- Release after long action: no Mouse Mode action.
- A new cycle is allowed only after both controls are released.
- Back/Start gameplay actions are suppressed while the chord is active or locked.
- A subtle progress bar appears only after 12% of the hold threshold.

## Bindings launcher

The launcher position is normalized and migrates once from legacy right/top offsets. It can be dragged only while the editor is open. Its existing left-click toggle behavior remains unchanged during normal play.
