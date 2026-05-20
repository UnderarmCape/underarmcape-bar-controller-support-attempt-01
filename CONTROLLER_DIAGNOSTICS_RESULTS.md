\# Controller Diagnostics Results



Date: 2026-05-21  

Branch: underarmcape/bar-controller-support-attempt-01  

Widget: `luaui/Widgets/gui\_controller\_diagnostics.lua`



\## Result



The diagnostics widget loads successfully in BAR LuaUI, but the current running engine build does not expose controller APIs to Lua.



Observed log output:



```text

\[ControllerDiag], Initializing controller diagnostics widget.

\[ControllerDiag], Controller API incomplete or unavailable.

\[ControllerDiag], GetAvailableControllers:, no

\[ControllerDiag], ConnectController:, no

\[ControllerDiag], DisconnectController:, no

\[ControllerDiag], GetControllerState:, no

\[ControllerDiag], Spring.GetAvailableControllers is not available. Controller API may not exist in this engine build.

