# Controller UI Authoring input ownership

## Scope

This audit compares the deployed Controller UI Layout widget at commit
`5f391d422f8fad9af2eb299bdf279f45f296b075` with the BAR widget handler in
`luaui/barwidgets.lua`, the installed Recoil 2026.06.12 handler, and working BAR
modal widgets including `gui_options.lua`, `gui_chat.lua`, and
`widget_selector.lua`.

The settings model, schema-3 documents, glyph resolver, themes, favorites,
presets, and production controller behavior are not implicated. The failure is
in the authoring shell's integration with BAR's input dispatcher.

## BAR/Recoil conventions found

- `barwidgets.lua` stores call-in lists in ascending widget-layer order and
  invokes `MousePress`, `MouseWheel`, and `KeyPress` from the beginning of those
  lists. A lower (more negative) layer therefore receives interactive input
  before a higher layer. BAR's Options widget uses layer `-99990` for this
  reason.
- A `MousePress` returning `true` becomes `widgetHandler.mouseOwner`. Subsequent
  `MouseMove` and `MouseRelease` call-ins are routed to that owner until every
  mouse button is released.
- `widget:IsAbove(x, y)` participates in the handler's viewport/UI hit result.
  A modal shield must return `true` across the whole viewport while open.
- `MouseWheel` must return `true` even when no editor control changes, otherwise
  the engine camera remains eligible to consume the wheel.
- BAR routes `textOwner:KeyPress` before action-handler gameplay bindings. Text
  ownership is the native way to prevent gameplay actions while a text-capable
  modal is active.
- Working BAR text fields claim `widgetHandler.textOwner` and call
  `Spring.SDLStartTextInput()`. They release ownership and call
  `Spring.SDLStopTextInput()` when editing ends.
- `TextInput` supplies committed UTF-8 text. The installed handler also exposes
  `TextEditing` for in-progress IME composition.
- `RaiseWidget` only changes order among widgets on the same layer. Modal input
  priority therefore starts with an appropriate layer and is reinforced by
  raising on open.

## Why mouse clicks reached gameplay

The editor widget used layer `1000001`, which put it behind nearly every BAR
mouse consumer even though that value visually looked like a "high" layer. It
also had no `IsAbove` call-in. Its hit routing only treated the editor rectangle
as the editor surface; it had no full-viewport modal shield. `MouseMove` and
`MouseRelease` returned ownership only for a subset of active drags, rather than
maintaining a single captured control through release.

Consequently a working BAR or gameplay widget could receive the press first,
and the engine did not see a UI surface above the world outside the editor
rectangle. Right-click orders, selection clicks, and camera-wheel input could
therefore execute before or instead of the editor action.

## Why property controls did not execute

The immediate-mode workspace resolves overlapping hits from the most recently
registered item to the earliest item. Property rows registered their slider,
toggle, or value field first and then registered the full parent row over the
same rectangle. Reverse hit testing therefore returned the parent selection
action before it could ever return the child control action. The controls were
drawn but were not the interactive surface under the pointer.

The repaired workspace registers the parent row first and its concrete child
controls afterward. This preserves row selection and right-click property menus
while giving toggles, step buttons, sliders, typed values, and wheel adjustment
the expected hit priority.

## Why keyboard navigation did not execute

Normal BAR key actions run before ordinary widget `KeyPress` call-ins. The old
shell depended on direct assignment to `widgetHandler.textOwner`, but it did not
establish the complete native lifecycle: it did not start SDL text input, did
not implement `TextEditing`, did not reassert modal ownership after another UI
changed ownership, and did not clear held/captured state on focus loss. With the
widget at the wrong interaction layer, loss of that fragile text-owner claim
left the action handler and earlier widgets ahead of the editor.

The workspace harness called focus and scrolling functions directly. It proved
the internal list arithmetic, but not call-in registration, layer ordering,
text ownership, mouse ownership, or return values through BAR's dispatcher.

## Decision

Repair the workspace's presentation/state model, but replace its input boundary
with an explicit native modal shell:

1. use a modal BAR layer and raise the widget when the editor opens;
2. report `IsAbove=true` for the entire viewport while open;
3. consume every mouse button, release, wheel, keyboard event, and text event;
4. capture one concrete editor control from press through release;
5. claim/release BAR text ownership and SDL text input as one lifecycle;
6. clear capture, held-key, edit, and composition state on close, shutdown, and
   focus loss;
7. keep editor chrome in workspace state rather than controller-UI undo data.

The data and renderer registries remain in place. Only the unreliable
interaction shell is replaced or extended.
