# Lua Widget Refactor

The native Build Menu’s `widget:DrawScreen` had reached BAR’s 60-upvalue limit. Hidden-panel refresh and visible-panel command/texture refresh are now cohesive top-level functions. `DrawScreen` is 52 upvalues, with no changed function above 55 and no deployed function above BAR’s limit.

Controller tap timing is isolated in `controller_selection_taps.lua`. These splits avoid a second input widget, duplicate polling, per-frame model rebuilds, and cross-widget table chatter.
