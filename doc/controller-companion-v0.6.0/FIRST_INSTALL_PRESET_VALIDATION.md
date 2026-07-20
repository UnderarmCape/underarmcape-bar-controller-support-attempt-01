# First-install preset validation

## Root cause and ownership

Gameplay binding definitions previously defaulted `commandLayer` to RT, while the bindings UI contained a separate table that changed it to Back/View when `Build-First Commander` was clicked. The button therefore repaired a fresh configuration.

The gameplay widget now owns one `ControllerCameraTestBuildFirstPreset` table. Binding definitions derive defaults from it, reset-all calls its preset application function, the bindings UI calls the same function, and preset details query that same table.

## Persistence rules

Binding config schema is 2. A complete saved table is valid only when every current action is present and every value is a supported button, trigger, or `none`. Complete schema-1/legacy tables migrate without changes. Valid custom mappings are retained and marked `Custom`. Fresh, empty, partial, malformed, or explicitly unsupported schemas receive Build-First once during config load/default construction; the preset is not reapplied each launch.

## Targeted validation

1. With no Controller Camera Test config, start a match without opening Bindings.
2. Confirm command layer is Back/View, build/factory radial is RB, queue append is RT, and placement bindings match Build-First.
3. Open Bindings and confirm `Build-First Commander` is Active.
4. Rebind one action, restart, and confirm it remains changed and the preset status is Custom.
5. Restore the test config backup after the clean-config test.
