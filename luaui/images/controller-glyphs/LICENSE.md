# Controller glyph asset license and source

`controller_glyph_atlas.png` is original generic controller/input artwork created specifically for BAR Controller Companion on 2026-07-20. It was generated from geometric primitives and text by `tools/dev-scripts/Generate_Controller_Glyph_Atlas.ps1`.

The experimental `controller_glyph_atlas_xbox.png` and `controller_glyph_atlas_playstation.png` are original deterministic geometric drawings produced by `tools/dev-scripts/Generate_Controller_Glyph_Atlases_v0.8.ps1`. Their visual direction was informed by a user-supplied local reference archive (`XBOX and PS Glyps.zip`, SHA-256 `b1e0ddec4c649b404390fc2e486ec796ecbaf0e21781e5cb8a5489873d9397c4`). No file from that archive is bundled or redistributed. The archive's provenance and redistribution rights are unverified; they must be reviewed before any public v0.8.0 release.

The five D-pad cells in both experimental atlases are copied pixel-for-pixel from the v0.7.0 project atlas so that the approved D-pad artwork remains unchanged.

Copyright (c) 2026 Kailil and BAR Controller Companion contributors.

SPDX asset license identifiers: `GPL-2.0-or-later OR CC0-1.0`.

The atlas, its generator source, and the glyph metadata in `LuaUI/Include/controller_glyphs.lua` are licensed under the GNU General Public License, version 2 or (at your option) any later version, consistently with the widget code. They may also be redistributed under CC0 1.0 where a standalone asset-only license is required.

Button letters, generic input names, and platform-layout symbols are functional labels. Microsoft, Xbox, Sony, PlayStation, DualSense, and DualShock names remain the property of their respective owners and are used only to describe controller-family compatibility.
