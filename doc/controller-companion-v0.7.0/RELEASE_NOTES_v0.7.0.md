# BAR Controller Support v0.7.0 — Disassemble Mode & Streamlined Runtime

## Highlights

- Persistent Disassemble Mode entered or exited with a one-second LB+RB hold.
- Reclaim-capable units are detected from the actual selection and live command capability, then validated throughout the mode.
- Friendly units and structures have a separate marked-target set; tap, toggle, filtered area marking, and visual outlines never replace the reclaimer selection.
- RT+A adds or removes a hovered friendly unit or structure from the normal game selection.
- LB+A taps issue a direct single-target reclaim. Holding LB+A enters modal same-type area reclaim; release does nothing, A or X confirms, and B cancels.
- LB+B cancels active targeting and sends Stop only to captured reclaimers.
- A 20-second timeout exits an unused mode session; the first successful reclaim disarms it.
- LB+RB filter-radial coexistence and neutral-direction latching are corrected.
- Build failures explain technology, limit, or command unavailability; affordable and unaffordable entries remain actionable with exact metal/energy deficits.
- Metal, energy, and health labels are icons with measured spacing and independent semantic styling. Obsolete radial footer prompts are gone while page/category information remains.
- Controller UI Layout no longer runs in normal gameplay. A lean runtime preserves the exact shipped v0.6.1 hint model and Bindings button position; the authoring widget remains optional through F11.

## Install

Download and verify `BAR_Controller_Support_v0.7.0_Widget_Companion.zip`, extract it, run `BAR_Controller_Companion_Installer_v0.7.0.exe`, and launch BAR through the normal patched shortcut. SmartScreen may warn because the executables are unsigned. No custom Recoil engine is installed or required.

## Upgrade

v0.6.1 users retain bindings, hint appearance, Bindings button placement, radial styles, themes, presets, profiles, favorites, cached defaults, recovery drafts, and personal settings. Controller UI Layout is disabled for gameplay but its data is preserved and it remains an optional F11 widget.

## Restore and integrity

Use `BAR_Controller_Companion_Restore_v0.7.0.exe` to restore the recorded transaction. Verify the public ZIP with its `.sha256` asset and extracted files with `payload-sha256.json`.
