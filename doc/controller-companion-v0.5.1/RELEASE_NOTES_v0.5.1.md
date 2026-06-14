# BAR Controller Companion v0.5.1 Release Notes

Public release:

- Title: `BAR Controller Support v0.5.1 — Widget + Companion Gameplay Fixes`
- Tag: `controller-support-v0.5.1-gameplay-fixes`
- Asset: `BAR_Controller_Support_v0.5.1_Widget_Companion.zip`
- Checksum: `BAR_Controller_Support_v0.5.1_Widget_Companion.zip.sha256`

## Gameplay Fixes

1. Tactical radial Area Mex visibility now follows mex-constructor capability.
   Eligible constructors and commanders receive the entry; other units do not.
2. Hold X with multiple selected units now issues a Move path instead of Fight.
3. Smart X with a T2 construction bot on an existing T1 mex no longer calls the
   unavailable `Spring.GetUnitFacing` API and no longer crashes the controller
   widget.

## Preserved Behavior

- Normal Smart X remains functional.
- Build menus and other radials remain functional.
- The v0.5.0 bridge, launcher, installer, restore, shortcut patching, required
  widget enablement, and camera-setting workflow remain in place.
- No custom Recoil engine is required.

## Validation

The three gameplay fixes passed live manual testing. Automated release checks
cover Lua parsing, .NET builds, isolated installer/restore behavior, staged
package structure, manifest version, updated widget contents, and ZIP checksum.

The final SHA256 is published in the adjacent `.sha256` release asset and in
the GitHub release notes.
