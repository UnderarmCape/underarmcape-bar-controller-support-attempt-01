# Tactical state cycling

Native state descriptors remain authoritative. For a three-or-more-state command, A computes `(current + 1) % count` and X computes `(current - 1) % count`, then `gui_ordermenu.lua:controllerActivateState` applies that exact state across the compatible selection. Move State and Fire State therefore cycle forward and backward without opening another radial. Binary states retain their direct toggle.

The old three-state sub-radial input and rendering code was removed. After activation the native tactical model is rebuilt so the focused item and center detail show the resulting live state.
