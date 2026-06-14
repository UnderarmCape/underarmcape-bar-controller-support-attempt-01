# BAR Controller Companion v0.5.0 Release Notes

Public release:

- Title: `BAR Controller Support v0.5.0 — Widget + Companion Release`
- Tag: `controller-support-v0.5.0-widget-companion`
- Asset: `BAR_Controller_Support_v0.5.0_Widget_Companion.zip`
- Checksum: `BAR_Controller_Support_v0.5.0_Widget_Companion.zip.sha256`
- SHA256: `584f20ad10afdfbb35ccab247b69f0173c72ea6a7388ba01c3597cd0cef7213e`

## Highlights

- Adds a companion UDP bridge for controller support on standard BAR.
- Requires no custom Recoil engine.
- Adds native installer and restore executables; PowerShell is no longer the
  normal user path.
- Patches normal BAR shortcuts through a small launcher that starts the bridge
  minimized and exits after launching BAR.
- Automatically enables exactly `Controller Camera Test` and
  `Controller Bindings UI`.
- Applies `CamSpringLockCardinalDirections = 0` with backup-aware editing.
- Keeps install state and first-install backups for idempotent reinstall and
  cautious restore behavior.
- Makes bridge logging quiet by default and adds `--verbose` packet-rate output.
- Keeps bundled local installation as the offline default, with an optional
  validated GitHub release check.

## Restore Behavior

The restore executable restores recorded shortcuts, overwritten widgets, and
the prior widget config. It leaves newly installed files in place. Camera
settings remain at `0` unless `--restore-camera` is supplied.

## Known Unfixed Gameplay Bugs

1. Area Mex is missing from the tactical radial for builders and commanders.
2. Hold X plus drag with multiple selected units sends Fight instead of Move.
3. Smart X with a T2 construction bot on a completed T1 mex can crash
   `gui_controller_camera_test.lua`.
