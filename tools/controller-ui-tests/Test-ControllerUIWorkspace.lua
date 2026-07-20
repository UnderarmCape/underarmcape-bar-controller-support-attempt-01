local root = (arg and arg[1]) or "."

local function assertTrue(value, label)
	if not value then error(label .. ": expected true", 2) end
end

local function assertEqual(actual, expected, label)
	if actual ~= expected then error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2) end
end

local scissorCalls = 0
gl = setmetatable({
	Color = function() end, Rect = function() end, Text = function() end,
	Scissor = function() scissorCalls = scissorCalls + 1 end,
}, { __index = function() return function() end end })
Spring = { GetMouseState = function() return 0, 0 end }

local Workspace = dofile(root .. "/luaui/Include/controller_ui_editor_workspace.lua")
local state = Workspace.New()
local bounds = { x1 = 100, y1 = 80, x2 = 1300, y2 = 840 }

Workspace.SetBounds(state, bounds)
assertTrue(state.layout.preview ~= nil, "wide layout has preview")
Workspace.SetBounds(state, { x1 = 0, y1 = 0, x2 = 760, y2 = 600 })
assertTrue(state.layout.preview == nil, "compact layout hides preview")
Workspace.SetBounds(state, { x1 = 0, y1 = 0, x2 = 720, y2 = 600 })
assertTrue(state.layout.navCollapsed, "narrow layout collapses navigation")

local rows = {}
for index = 1, 80 do
	rows[index] = { "stress", "p" .. index, "Stress property " .. index, "number", 0, 100, 1, index > 60 and "Advanced" or "Basic" }
end

local theme = {
	backgroundR = 0.02, backgroundG = 0.03, backgroundB = 0.04,
	foregroundR = 0.94, foregroundG = 0.98, foregroundB = 1,
	accentR = 0.34, accentG = 0.82, accentB = 0.92,
	mutedR = 0.36, mutedG = 0.52, mutedB = 0.60,
	dangerR = 0.92, dangerG = 0.28, dangerB = 0.24,
}

local components = {
	{ id = "general", label = "General", icon = "G", group = "Interface" },
	{ id = "hints", label = "Button Hints", icon = "H", group = "Interface" },
	{ id = "advanced", label = "Advanced", icon = "A", group = "System" },
}

local spec = {
	bounds = bounds, theme = theme, title = "Test workspace", rows = rows, selectedRow = 1,
	components = components, selectedNav = "general", tabName = "Stress", filterMode = "Basic",
	search = "", previewContext = "Long Binding Stress Test", previewLabel = "Button Hints",
	previewWidth = 570, previewHeight = 150,
	getValue = function(row) return tonumber(string.match(row[2], "%d+")) or 0 end,
	getSource = function() return "test" end,
	isModified = function() return false end, isEnforced = function() return false end,
}

Workspace.Draw(state, spec)
assertTrue(scissorCalls >= 4, "navigation and inspector clipping")
assertTrue(state.panes.inspector.maxScroll > state.panes.inspector.viewport * 3, "stress list spans several screens")
assertTrue(state.panes.inspector.thumb ~= nil, "visible inspector scrollbar")

assertTrue(Workspace.SetFocus(state, "property:stress.p1"), "first property focusable")
assertEqual(state.panes.inspector.scroll, 0, "first property at top")
assertTrue(Workspace.SetFocus(state, "property:stress.p40"), "middle property focusable")
assertTrue(state.panes.inspector.scroll > 0 and state.panes.inspector.scroll < state.panes.inspector.maxScroll, "middle property scrolls into view")
assertTrue(Workspace.SetFocus(state, "property:stress.p80"), "final property focusable")
assertEqual(state.panes.inspector.scroll, state.panes.inspector.maxScroll, "final property reaches scroll end")

local beforePage = state.panes.inspector.scroll
Workspace.Page(state, -1)
assertTrue(state.panes.inspector.scroll < beforePage, "page up scrolls one viewport")
Workspace.Page(state, 1)
assertTrue(state.panes.inspector.scroll > 0, "page down scrolls inspector")

Workspace.FocusBoundary(state, false)
assertEqual(state.focusId, state.focusItems[1].id, "home reaches first focus target")
Workspace.FocusBoundary(state, true)
assertEqual(state.focusId, state.focusItems[#state.focusItems].id, "end reaches final focus target")
local last = state.focusId
Workspace.MoveFocus(state, 1)
assertEqual(state.focusId, state.focusItems[1].id, "tab order wraps")
Workspace.MoveFocus(state, -1)
assertEqual(state.focusId, last, "reverse tab order wraps")

local inspector = state.layout.inspector
local oldInspector = state.panes.inspector.scroll
assertTrue(Workspace.MouseWheel(state, inspector.x1 + 20, inspector.y1 + 80, -1, false), "wheel consumed over inspector")
assertTrue(state.panes.inspector.scroll >= oldInspector, "wheel routes to inspector")
local nav = state.layout.nav
local oldNav = state.panes.nav.scroll
local inspectorBeforeNavWheel = state.panes.inspector.scroll
assertTrue(Workspace.MouseWheel(state, nav.x1 + 10, nav.y1 + 20, -1, false), "wheel consumed over component browser")
assertEqual(state.panes.inspector.scroll, inspectorBeforeNavWheel, "nav wheel does not change inspector")
assertTrue(state.panes.nav.scroll >= oldNav, "wheel routes independently to navigation")
assertTrue(not Workspace.MouseWheel(state, bounds.x2 + 10, bounds.y2 + 10, -1, false), "wheel outside editor not consumed")

state.panes.inspector.scroll = 0
Workspace.UpdatePane(state, "inspector", 4000, 500, { x1 = 900, y1 = 100, x2 = 1250, y2 = 600 })
local track = state.panes.inspector.track
assertTrue(Workspace.ScrollbarPress(state, (track.x1 + track.x2) * 0.5, track.y1 + 2), "scrollbar track click handled")
assertTrue(state.panes.inspector.scroll > 0, "track click pages")
local thumb = state.panes.inspector.thumb
assertTrue(Workspace.ScrollbarPress(state, (thumb.x1 + thumb.x2) * 0.5, (thumb.y1 + thumb.y2) * 0.5), "scrollbar thumb drag begins")
local dragBefore = state.panes.inspector.scroll
Workspace.ScrollbarDrag(state, thumb.y1 - 40)
assertTrue(state.panes.inspector.scroll > dragBefore, "dragging thumb downward advances content")
assertTrue(Workspace.EndPointer(state), "scrollbar drag ends")

Workspace.SetInspectorKey(state, "first")
state.panes.inspector.scroll = 321
Workspace.SetInspectorKey(state, "second")
state.panes.inspector.scroll = 123
Workspace.SetInspectorKey(state, "first")
assertEqual(state.panes.inspector.scroll, 321, "inspector scroll persists per component")

local propertyItems, expandedHeight = Workspace.PropertyItems(rows, state.collapsed, "Basic", { stress = "Stress" })
assertTrue(#propertyItems > #rows, "property list includes collapsible group")
Workspace.ToggleGroup(state, "stress")
local collapsedItems, collapsedHeight = Workspace.PropertyItems(rows, state.collapsed, "Basic", { stress = "Stress" })
assertEqual(#collapsedItems, 1, "collapsed property group hides rows")
assertTrue(collapsedHeight < expandedHeight, "collapse updates scroll range input")
Workspace.ToggleGroup(state, "stress")

local results = Workspace.ComponentSearchResults(components, "button")
assertEqual(#results, 1, "component search returns matching result")
assertEqual(results[1].id, "hints", "component search selects expected result")

Workspace.Draw(state, spec)
Workspace.SetFocus(state, "property:stress.p40")
local opener = state.focusId
Workspace.OpenModal(state, "Choose", {
	{ label = "First", action = "first" }, { label = "Disabled", action = "disabled", disabled = true },
	{ label = "Final", action = "final" },
}, opener)
Workspace.Draw(state, spec)
assertEqual(#state.focusItems, 2, "modal skips disabled option")
for _, item in ipairs(state.focusItems) do assertTrue(string.find(item.id, "modal:", 1, true) == 1, "modal traps focus") end
Workspace.MoveFocus(state, 1)
assertEqual(state.focusId, "modal:3", "modal keyboard navigation")
assertTrue(Workspace.CloseModal(state), "modal closes")
Workspace.Draw(state, spec)
assertEqual(state.focusId, opener, "modal restores opener focus")

print("Controller UI workspace tests passed: responsive panes, clipping, independent wheel scrolling, scrollbars, first/middle/final reachability, focus order, paging, search, collapse, per-component scroll, and modal trapping.")
