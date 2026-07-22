# Tactical radial toggle

Back/View held plus a fresh RB press is detected before distributed placement,
Disassemble/Factory shoulder arbitration, and Build/Factory opening. It toggles
the Tactical Radial and latches until RB is released. The release frame is also
consumed, preventing a delayed Build/Factory open.

Opening Tactical closes any Build/Factory radial first. While Tactical is open,
`ControllerCameraTestOpenBuildMenu` rejects every open request and shoulder
arbitration yields to the Tactical input handler. Repeating Back/View+RB closes
Tactical; a later RB action requires a new clean press.
