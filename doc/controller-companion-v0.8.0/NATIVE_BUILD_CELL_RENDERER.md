# Shared native Build Menu cell renderer

`luaui/Include/controller_native_build_cell_renderer.lua` is the one renderer used by both vanilla `gui_buildmenu.lua` cells and Native Experimental Build/Factory radial entries. The grid passes its exact geometry, padding, zoom, font, costs and overrides, disabled/under-construction state, radar/group badge textures, queue count, and selected tint. The radial passes the same exported command data at radial geometry.

The renderer uses BAR FlowUI's `Draw.Unit` path, including the native unit texture crop, disabled tint prefixes for icon badges, metal/energy colors and formatting, native three-layer queue badge, and both selected-tint blend passes. The radial still draws its controller focus border and sector background outside the cell; that treatment does not replace or approximate the native cell.

Quota data remains grid-owned because it is builder-instance state not currently exported by the controller item snapshot. This is the only known per-cell visual limitation.
