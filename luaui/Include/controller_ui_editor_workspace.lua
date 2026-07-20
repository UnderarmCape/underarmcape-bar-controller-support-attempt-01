--------------------------------------------------------------------------------
-- Controller UI authoring workspace
-- Pure layout/input state plus an immediate-mode BAR renderer.
--------------------------------------------------------------------------------

local Workspace = {}

local max, min, floor = math.max, math.min, math.floor

local function clamp(value, low, high)
	value = tonumber(value) or low
	return max(low, min(high, value))
end

local function inside(bounds, x, y)
	return bounds and x >= bounds.x1 and x <= bounds.x2 and y >= bounds.y1 and y <= bounds.y2
end

local function copyBounds(bounds)
	return { x1 = bounds.x1, y1 = bounds.y1, x2 = bounds.x2, y2 = bounds.y2,
		width = bounds.x2 - bounds.x1, height = bounds.y2 - bounds.y1 }
end

local function paneState()
	return { scroll = 0, content = 0, viewport = 0, maxScroll = 0, track = nil, thumb = nil }
end

function Workspace.New()
	return {
		panes = { nav = paneState(), inspector = paneState(), preview = paneState() },
		inspectorScroll = {}, collapsed = {}, navGroups = {}, componentSearch = "",
		focusId = nil, focusItems = {}, focusIndex = 0, hits = {}, modal = nil,
		dragScrollbar = nil, hovered = nil, previewZoom = 1, previewFit = true,
		showHelp = false, navCollapsed = false, forcedNavCollapsed = false,
	}
end

function Workspace.SetBounds(state, bounds)
	state.bounds = copyBounds(bounds)
	local width, bodyGap = state.bounds.width, 6
	local headerH, toolbarH, footerH = 48, 40, 42
	local body = { x1 = bounds.x1 + 8, y1 = bounds.y1 + footerH, x2 = bounds.x2 - 8,
		y2 = bounds.y2 - headerH - toolbarH }
	local compact = width < 800
	local forcedCollapse = width < 735
	state.forcedNavCollapsed = forcedCollapse
	local collapsed = forcedCollapse or state.navCollapsed
	local navW = collapsed and 48 or clamp(width * 0.22, 164, 210)
	local inspectorW = compact and (body.x2 - body.x1 - navW - bodyGap)
		or clamp(width * 0.45, 330, 470)
	state.layout = {
		header = { x1 = bounds.x1, y1 = bounds.y2 - headerH, x2 = bounds.x2, y2 = bounds.y2 },
		toolbar = { x1 = bounds.x1 + 8, y1 = bounds.y2 - headerH - toolbarH, x2 = bounds.x2 - 8, y2 = bounds.y2 - headerH },
		footer = { x1 = bounds.x1 + 8, y1 = bounds.y1 + 5, x2 = bounds.x2 - 8, y2 = bounds.y1 + footerH - 4 },
		nav = { x1 = body.x1, y1 = body.y1, x2 = body.x1 + navW, y2 = body.y2 },
		inspector = { x1 = body.x2 - inspectorW, y1 = body.y1, x2 = body.x2, y2 = body.y2 },
		compact = compact, navCollapsed = collapsed,
	}
	if not compact then
		state.layout.preview = { x1 = state.layout.nav.x2 + bodyGap, y1 = body.y1,
			x2 = state.layout.inspector.x1 - bodyGap, y2 = body.y2 }
	end
	return state.layout
end

local function updatePane(pane, content, viewport)
	pane.content, pane.viewport = max(0, content or 0), max(0, viewport or 0)
	pane.maxScroll = max(0, pane.content - pane.viewport)
	pane.scroll = clamp(pane.scroll, 0, pane.maxScroll)
end

local function scrollbarFor(pane, bounds)
	if not bounds or pane.maxScroll <= 0 or pane.viewport <= 0 then
		pane.track, pane.thumb = nil, nil
		return nil
	end
	local track = { x1 = bounds.x2 - 10, y1 = bounds.y1, x2 = bounds.x2 - 2, y2 = bounds.y2 }
	local trackH = track.y2 - track.y1
	local thumbH = clamp(trackH * (pane.viewport / pane.content), 28, trackH)
	local travel = max(0, trackH - thumbH)
	local ratio = pane.maxScroll > 0 and pane.scroll / pane.maxScroll or 0
	local thumbY2 = track.y2 - ratio * travel
	pane.track = track
	pane.thumb = { x1 = track.x1, y1 = thumbY2 - thumbH, x2 = track.x2, y2 = thumbY2 }
	return pane.thumb
end

function Workspace.UpdatePane(state, name, content, viewport, bounds)
	local pane = state.panes[name]
	if not pane then return end
	updatePane(pane, content, viewport)
	scrollbarFor(pane, bounds)
end

function Workspace.SetInspectorKey(state, key)
	key = tostring(key or "default")
	if state.inspectorKey == key then return end
	if state.inspectorKey then state.inspectorScroll[state.inspectorKey] = state.panes.inspector.scroll end
	state.inspectorKey = key
	state.panes.inspector.scroll = state.inspectorScroll[key] or 0
end

function Workspace.Scroll(state, name, delta)
	local pane = state.panes[name]
	if not pane then return false end
	local before = pane.scroll
	pane.scroll = clamp(pane.scroll + delta, 0, pane.maxScroll)
	if name == "inspector" and state.inspectorKey then state.inspectorScroll[state.inspectorKey] = pane.scroll end
	return pane.scroll ~= before
end

function Workspace.MouseWheel(state, x, y, direction, shift)
	if not inside(state.bounds, x, y) then return false end
	local layout = state.layout or {}
	local paneName = inside(layout.nav, x, y) and "nav" or inside(layout.inspector, x, y) and "inspector" or nil
	if paneName then
		local amount = shift and 24 or 72
		Workspace.Scroll(state, paneName, direction > 0 and -amount or amount)
	end
	return true
end

function Workspace.ScrollbarPress(state, x, y)
	for _, name in ipairs({ "nav", "inspector" }) do
		local pane = state.panes[name]
		if inside(pane.thumb, x, y) then
			state.dragScrollbar = { name = name, startY = y, startScroll = pane.scroll }
			return true
		elseif inside(pane.track, x, y) then
			local direction = y > pane.thumb.y2 and -1 or 1
			Workspace.Scroll(state, name, direction * max(40, pane.viewport * 0.88))
			return true
		end
	end
	return false
end

function Workspace.ScrollbarDrag(state, y)
	local drag = state.dragScrollbar
	if not drag then return false end
	local pane = state.panes[drag.name]
	local travel = (pane.track.y2 - pane.track.y1) - (pane.thumb.y2 - pane.thumb.y1)
	if travel > 0 then
		Workspace.Scroll(state, drag.name, (y - drag.startY) * -pane.maxScroll / travel + drag.startScroll - pane.scroll)
	end
	return true
end

function Workspace.EndPointer(state)
	local handled = state.dragScrollbar ~= nil
	state.dragScrollbar = nil
	return handled
end

local function addFocus(state, item)
	if item and not item.disabled then state.focusItems[#state.focusItems + 1] = item end
end

local function addHit(state, hit, focusable)
	state.hits[#state.hits + 1] = hit
	if focusable then addFocus(state, hit) end
	return hit
end

local function focused(state, id)
	return state.focusId == id
end

local function findFocus(state, id)
	for index, item in ipairs(state.focusItems) do
		if item.id == id then return index, item end
	end
	return nil, nil
end

local function ensureFocusExists(state)
	local index = state.focusId and findFocus(state, state.focusId) or nil
	if not index then
		state.focusIndex = #state.focusItems > 0 and 1 or 0
		state.focusId = state.focusItems[1] and state.focusItems[1].id or nil
	else
		state.focusIndex = index
	end
end

function Workspace.EnsureFocusVisible(state)
	local _, item = findFocus(state, state.focusId)
	if not item or not item.virtualBounds or not item.pane then return false end
	local paneBounds = item.pane == "inspector" and state.inspectorViewport or state.navViewport
	local pane = state.panes[item.pane]
	if not paneBounds or not pane then return false end
	local top = item.virtualBounds.top
	local bottom = item.virtualBounds.bottom
	if top - pane.scroll > pane.viewport then pane.scroll = clamp(top - pane.viewport, 0, pane.maxScroll)
	elseif bottom - pane.scroll < 0 then pane.scroll = clamp(bottom, 0, pane.maxScroll) end
	if item.pane == "inspector" and state.inspectorKey then state.inspectorScroll[state.inspectorKey] = pane.scroll end
	return true
end

function Workspace.SetFocus(state, id)
	local index = findFocus(state, id)
	if not index then return false end
	state.focusId, state.focusIndex = id, index
	Workspace.EnsureFocusVisible(state)
	return true
end

function Workspace.MoveFocus(state, delta)
	if #state.focusItems == 0 then return nil end
	local index = state.focusIndex > 0 and state.focusIndex or 1
	index = ((index - 1 + delta) % #state.focusItems) + 1
	state.focusIndex, state.focusId = index, state.focusItems[index].id
	Workspace.EnsureFocusVisible(state)
	return state.focusItems[index]
end

function Workspace.FocusBoundary(state, last)
	if #state.focusItems == 0 then return nil end
	local index = last and #state.focusItems or 1
	state.focusIndex, state.focusId = index, state.focusItems[index].id
	Workspace.EnsureFocusVisible(state)
	return state.focusItems[index]
end

function Workspace.Page(state, direction)
	local _, item = findFocus(state, state.focusId)
	local paneName = item and item.pane or "inspector"
	local pane = state.panes[paneName] or state.panes.inspector
	Workspace.Scroll(state, paneName, direction * max(40, pane.viewport * 0.88))
	local wanted = direction > 0 and pane.scroll or pane.scroll + pane.viewport
	local candidate
	for _, focusItem in ipairs(state.focusItems) do
		if focusItem.pane == paneName and focusItem.virtualBounds then
			local distance = math.abs(focusItem.virtualBounds.bottom - wanted)
			if not candidate or distance < candidate.distance then candidate = { item = focusItem, distance = distance } end
		end
	end
	if candidate then Workspace.SetFocus(state, candidate.item.id) end
	return candidate and candidate.item or nil
end

function Workspace.Focused(state)
	local _, item = findFocus(state, state.focusId)
	return item
end

function Workspace.OpenModal(state, title, options, opener)
	state.modal = { title = tostring(title or "Choose"), options = options or {}, opener = opener or state.focusId, index = 1 }
	state.focusId = "modal:1"
end

function Workspace.CloseModal(state)
	if not state.modal then return false end
	local opener = state.modal.opener
	state.modal = nil
	state.focusId = opener
	return true
end

function Workspace.ToggleGroup(state, id)
	state.collapsed[id] = not state.collapsed[id]
	return state.collapsed[id]
end

function Workspace.FindHit(state, x, y)
	for index = #state.hits, 1, -1 do
		local hit = state.hits[index]
		if inside(hit, x, y) then return hit end
	end
	return nil
end

function Workspace.ComponentSearchResults(components, search)
	local result, needle = {}, string.lower(tostring(search or ""))
	for _, component in ipairs(components or {}) do
		local haystack = string.lower(tostring(component.label or "") .. " " .. tostring(component.group or ""))
		if needle == "" or string.find(haystack, needle, 1, true) then result[#result + 1] = component end
	end
	return result
end

local function groupTitle(scope, level, filterMode, labels)
	local title = labels and labels[scope] or tostring(scope or "Properties")
	if filterMode == "All" and level then title = title .. " / " .. level end
	return title
end

function Workspace.PropertyItems(rows, collapsed, filterMode, labels)
	local items, offset, previous = {}, 0, nil
	for index, row in ipairs(rows or {}) do
		local level = row[8] or "Basic"
		local group = tostring(row[1]) .. (filterMode == "All" and (":" .. level) or "")
		if group ~= previous then
			items[#items + 1] = { kind = "group", id = group, label = groupTitle(row[1], level, filterMode, labels), offset = offset, height = 30 }
			offset, previous = offset + 30, group
		end
		if not collapsed[group] then
			items[#items + 1] = { kind = "property", id = tostring(row[1]) .. "." .. tostring(row[2]), row = row,
				rowIndex = index, offset = offset, height = 54, group = group }
			offset = offset + 54
		end
	end
	return items, offset
end

local function themeColor(theme, role, alpha)
	local prefix = role == "background" and "background" or role == "accent" and "accent"
		or role == "muted" and "muted" or role == "danger" and "danger" or "foreground"
	return { theme[prefix .. "R"] or 1, theme[prefix .. "G"] or 1, theme[prefix .. "B"] or 1, alpha == nil and 1 or alpha }
end

local function setColor(color)
	gl.Color(color[1], color[2], color[3], color[4])
end

local function rect(bounds, color)
	setColor(color); gl.Rect(bounds.x1, bounds.y1, bounds.x2, bounds.y2)
end

local function outline(bounds, color, thickness)
	setColor(color); thickness = thickness or 1
	for line = 0, thickness - 1 do
		gl.Rect(bounds.x1 + line, bounds.y1 + line, bounds.x2 - line, bounds.y1 + line + 1)
		gl.Rect(bounds.x1 + line, bounds.y2 - line - 1, bounds.x2 - line, bounds.y2 - line)
		gl.Rect(bounds.x1 + line, bounds.y1 + line, bounds.x1 + line + 1, bounds.y2 - line)
		gl.Rect(bounds.x2 - line - 1, bounds.y1 + line, bounds.x2 - line, bounds.y2 - line)
	end
end

local function label(text, x, y, size, color, options)
	setColor(color); gl.Text(tostring(text or ""), x, y, size, options or "o")
end

local function focusOutline(state, bounds, id, color)
	if focused(state, id) then outline(bounds, color, 2) end
end

local function button(state, bounds, id, textValue, action, colors, tooltip, disabled)
	rect(bounds, disabled and colors.disabled or colors.button)
	outline(bounds, colors.border, 1)
	label(textValue, (bounds.x1 + bounds.x2) * 0.5, bounds.y1 + max(5, (bounds.y2 - bounds.y1 - 11) * 0.5), 10, colors.text, "oc")
	local hit = { x1 = bounds.x1, y1 = bounds.y1, x2 = bounds.x2, y2 = bounds.y2, id = id,
		action = action, tooltip = tooltip or textValue, accessibleLabel = tooltip or textValue, disabled = disabled }
	if not disabled then addHit(state, hit, true) end
	focusOutline(state, bounds, id, colors.focus)
	return hit
end

local function drawScrollbar(state, name, colors)
	local pane = state.panes[name]
	if not pane.track then return end
	rect(pane.track, colors.scrollTrack)
	rect(pane.thumb, state.dragScrollbar and state.dragScrollbar.name == name and colors.scrollActive or colors.scrollThumb)
	outline(pane.thumb, colors.border, 1)
end

local function beginClip(bounds)
	gl.Scissor(bounds.x1, bounds.y1, bounds.x2 - bounds.x1, bounds.y2 - bounds.y1)
end

local function endClip()
	gl.Scissor(false)
end

local function workspaceColors(theme)
	return {
		background = themeColor(theme, "background", 0.98), panel = { 0.025, 0.045, 0.058, 0.98 },
		panelAlt = { 0.038, 0.070, 0.086, 0.98 }, header = { 0.045, 0.110, 0.132, 0.99 },
		button = { 0.055, 0.125, 0.148, 0.98 }, disabled = { 0.04, 0.055, 0.062, 0.72 },
		selected = { 0.08, 0.24, 0.28, 0.98 }, row = { 0.032, 0.062, 0.075, 0.96 },
		rowAlt = { 0.038, 0.073, 0.086, 0.96 }, input = { 0.015, 0.028, 0.036, 0.99 },
		text = themeColor(theme, "foreground", 1), muted = themeColor(theme, "muted", 0.94),
		accent = themeColor(theme, "accent", 1), focus = themeColor(theme, "accent", 1),
		border = themeColor(theme, "muted", 0.50), danger = themeColor(theme, "danger", 0.82),
		scrollTrack = { 0.015, 0.028, 0.035, 0.92 }, scrollThumb = themeColor(theme, "muted", 0.78),
		scrollActive = themeColor(theme, "accent", 0.92),
	}
end

local function drawHeader(state, spec, colors)
	local bounds = state.layout.header
	rect(bounds, colors.header)
	label(spec.title or "Controller UI Authoring", bounds.x1 + 16, bounds.y1 + 17, 18, colors.text)
	if spec.dirty then
		rect({ x1 = bounds.x1 + 260, y1 = bounds.y1 + 20, x2 = bounds.x1 + 268, y2 = bounds.y1 + 28 }, colors.accent)
	end
	label(spec.status or "Ready", bounds.x1 + 282, bounds.y1 + 19, 10, colors.muted)
	local close = { x1 = bounds.x2 - 38, y1 = bounds.y1 + 10, x2 = bounds.x2 - 10, y2 = bounds.y2 - 10 }
	button(state, close, "header:close", "X", { type = "close" }, colors, "Close editor (Escape)")
	addHit(state, { x1 = bounds.x1, y1 = bounds.y1, x2 = close.x1 - 6, y2 = bounds.y2,
		id = "header:move", action = { type = "move-window" }, accessibleLabel = "Move editor window" }, false)
end

local function drawToolbar(state, spec, colors)
	local bounds, x = state.layout.toolbar, state.layout.toolbar.x1
	rect(bounds, colors.panelAlt)
	local defs = {
		{ "Undo", 50, "undo", "Undo (Ctrl+Z)", spec.canUndo == false },
		{ "Redo", 50, "redo", "Redo (Ctrl+Y)", spec.canRedo == false },
		{ "Save", 52, "save", "Save personal settings (Ctrl+S)" },
		{ "Preview: " .. tostring(spec.previewContext or "Live"), 154, "preview-context", "Change safe preview context" },
		{ "Align", 54, "align-menu", "Alignment and distribution tools" },
		{ "Help", 48, "help", "Keyboard help (F1)" },
	}
	for _, def in ipairs(defs) do
		local b = { x1 = x, y1 = bounds.y1 + 6, x2 = x + def[2], y2 = bounds.y2 - 6 }
		button(state, b, "toolbar:" .. def[3], def[1], { type = def[3] }, colors, def[4], def[5])
		x = b.x2 + 5
	end
	if spec.developer then
		local width = 64
		local draft = { x1 = bounds.x2 - 2 * width - 8, y1 = bounds.y1 + 6, x2 = bounds.x2 - width - 7, y2 = bounds.y2 - 6 }
		local publish = { x1 = bounds.x2 - width - 3, y1 = bounds.y1 + 6, x2 = bounds.x2, y2 = bounds.y2 - 6 }
		button(state, draft, "toolbar:draft", "Draft", { type = "draft" }, colors, "Save authoring draft (Ctrl+Shift+S)")
		button(state, publish, "toolbar:publish", "Publish", { type = "publish" }, colors, "Create explicit publish request (Ctrl+Alt+S)")
	end
end

local function navItems(state, components)
	local items, offset, previous = {}, 0, nil
	for _, component in ipairs(Workspace.ComponentSearchResults(components, state.componentSearch)) do
		local group = component.group or "Components"
		if group ~= previous then
			items[#items + 1] = { kind = "group", id = "nav-group:" .. group, label = group, offset = offset, height = 28 }
			offset, previous = offset + 28, group
		end
		if not state.navGroups[group] then
			items[#items + 1] = { kind = "component", id = "component:" .. component.id, component = component,
				offset = offset, height = 32 }
			offset = offset + 32
		end
	end
	return items, offset
end

local function drawNavSearch(state, pane, colors)
	local headerH = state.layout.navCollapsed and 42 or 72
	local collapse = { x1 = pane.x1 + 6, y1 = pane.y2 - 34, x2 = pane.x1 + 40, y2 = pane.y2 - 6 }
	button(state, collapse, "nav:collapse", state.layout.navCollapsed and ">" or "<", { type = "toggle-nav" }, colors,
		state.layout.navCollapsed and "Expand component browser" or "Collapse component browser", state.forcedNavCollapsed)
	if not state.layout.navCollapsed then
		label("Components", pane.x1 + 48, pane.y2 - 25, 12, colors.text)
		local search = { x1 = pane.x1 + 6, y1 = pane.y2 - 66, x2 = pane.x2 - 14, y2 = pane.y2 - 40 }
		rect(search, colors.input); outline(search, focused(state, "nav:search") and colors.focus or colors.border, focused(state, "nav:search") and 2 or 1)
		label(state.componentSearch ~= "" and state.componentSearch or "Find component", search.x1 + 7, search.y1 + 7, 10,
			state.componentSearch ~= "" and colors.text or colors.muted)
		addHit(state, { x1 = search.x1, y1 = search.y1, x2 = search.x2, y2 = search.y2, id = "nav:search",
			action = { type = "focus-component-search" }, tooltip = "Search components", accessibleLabel = "Search components" }, true)
	end
	return headerH
end

local function drawNav(state, spec, colors)
	local pane = state.layout.nav
	rect(pane, colors.panel)
	outline(pane, colors.border, 1)
	local headerH = drawNavSearch(state, pane, colors)
	local viewport = { x1 = pane.x1 + 4, y1 = pane.y1 + 4, x2 = pane.x2 - 2, y2 = pane.y2 - headerH }
	state.navViewport = viewport
	local items, content = navItems(state, spec.components)
	Workspace.UpdatePane(state, "nav", content, viewport.y2 - viewport.y1, viewport)
	local scroll = state.panes.nav.scroll
	beginClip(viewport)
	for _, item in ipairs(items) do
		local y2, y1 = viewport.y2 - item.offset + scroll, viewport.y2 - item.offset - item.height + scroll
		local virtual = { top = item.offset + item.height, bottom = item.offset }
		if item.kind == "group" then
			local action = { type = "toggle-nav-group", group = item.label }
			addFocus(state, { id = item.id, action = action, pane = "nav", virtualBounds = virtual, accessibleLabel = item.label .. " group" })
			if y2 >= viewport.y1 and y1 <= viewport.y2 and not state.layout.navCollapsed then
				local b = { x1 = viewport.x1 + 3, y1 = y1, x2 = viewport.x2 - 10, y2 = y2 }
				label((state.navGroups[item.label] and "+ " or "- ") .. item.label, b.x1 + 4, b.y1 + 8, 10, colors.muted)
				addHit(state, { x1 = b.x1, y1 = b.y1, x2 = b.x2, y2 = b.y2, id = item.id, action = action,
					tooltip = "Expand or collapse " .. item.label, accessibleLabel = item.label .. " group" }, false)
				focusOutline(state, b, item.id, colors.focus)
			end
		elseif item.kind == "component" then
			local component = item.component
			local action = { type = "select-component", component = component }
			addFocus(state, { id = item.id, action = action, pane = "nav", virtualBounds = virtual, accessibleLabel = component.label })
			if y2 >= viewport.y1 and y1 <= viewport.y2 then
				local selected = component.id == spec.selectedNav
				local b = { x1 = viewport.x1 + 3, y1 = y1 + 1, x2 = viewport.x2 - 10, y2 = y2 - 1 }
				rect(b, selected and colors.selected or colors.row)
				local short = component.icon or string.sub(component.label, 1, 1)
				label(short, b.x1 + 16, b.y1 + 9, 10, selected and colors.accent or colors.muted, "oc")
				if not state.layout.navCollapsed then label(component.label, b.x1 + 33, b.y1 + 9, 10, colors.text) end
				addHit(state, { x1 = b.x1, y1 = b.y1, x2 = b.x2, y2 = b.y2, id = item.id, action = action,
					tooltip = component.label, accessibleLabel = component.label }, false)
				focusOutline(state, b, item.id, colors.focus)
			end
		end
	end
	endClip()
	drawScrollbar(state, "nav", colors)
end

local function previewShape(spec, pane)
	local sourceW = spec.previewWidth or 420
	local sourceH = spec.previewHeight or 180
	local availableW, availableH = pane.x2 - pane.x1 - 34, pane.y2 - pane.y1 - 116
	local fit = min(availableW / sourceW, availableH / sourceH)
	local zoom = spec.previewFit and fit or min(fit, fit * (spec.previewZoom or 1))
	local width, height = max(36, sourceW * zoom), max(28, sourceH * zoom)
	local cx, cy = (pane.x1 + pane.x2) * 0.5, (pane.y1 + pane.y2 - 20) * 0.5
	return { x1 = cx - width * 0.5, y1 = cy - height * 0.5, x2 = cx + width * 0.5, y2 = cy + height * 0.5 }
end

local function drawPreview(state, spec, colors)
	local pane = state.layout.preview
	if not pane then return end
	rect(pane, { 0.012, 0.023, 0.031, 0.98 }); outline(pane, colors.border, 1)
	label("LIVE PREVIEW", pane.x1 + 12, pane.y2 - 24, 10, colors.muted)
	label(spec.previewLabel or "Selected component", pane.x1 + 12, pane.y2 - 44, 14, colors.text)
	if tostring(spec.previewContext or "Live") ~= "Live" then
		label("SIMULATED / NO GAMEPLAY COMMANDS", pane.x1 + 12, pane.y2 - 61, 9, colors.accent)
	end
	local fit = { x1 = pane.x2 - 112, y1 = pane.y2 - 34, x2 = pane.x2 - 76, y2 = pane.y2 - 8 }
	local less = { x1 = pane.x2 - 72, y1 = pane.y2 - 34, x2 = pane.x2 - 42, y2 = pane.y2 - 8 }
	local more = { x1 = pane.x2 - 38, y1 = pane.y2 - 34, x2 = pane.x2 - 8, y2 = pane.y2 - 8 }
	button(state, fit, "preview:fit", "Fit", { type = "preview-fit" }, colors, "Fit selected component in preview")
	button(state, less, "preview:zoom-out", "-", { type = "preview-zoom", delta = -0.1 }, colors, "Zoom preview out")
	button(state, more, "preview:zoom-in", "+", { type = "preview-zoom", delta = 0.1 }, colors, "Zoom preview in")
	for line = 1, 5 do
		local y = pane.y1 + (pane.y2 - pane.y1) * line / 6
		rect({ x1 = pane.x1 + 10, y1 = y, x2 = pane.x2 - 10, y2 = y + 1 }, { colors.muted[1], colors.muted[2], colors.muted[3], 0.10 })
	end
	local shape = previewShape({ previewWidth = spec.previewWidth, previewHeight = spec.previewHeight,
		previewFit = state.previewFit, previewZoom = state.previewZoom }, pane)
	rect(shape, { colors.accent[1] * 0.18, colors.accent[2] * 0.22, colors.accent[3] * 0.24, 0.92 })
	outline(shape, colors.accent, 2)
	label(spec.previewLabel or "Component", (shape.x1 + shape.x2) * 0.5, (shape.y1 + shape.y2) * 0.5 - 5, 12, colors.text, "oc")
	label(spec.previewDetail or "Drag and resize in the live view", pane.x1 + 12, pane.y1 + 16, 9, colors.muted)
	if type(spec.drawPreview) == "function" then spec.drawPreview(shape, colors) end
end

local function valueText(spec, row)
	local value = spec.getValue(row)
	if row[4] == "bool" then return value and "ON" or "OFF" end
	if row[4] == "number" then return string.format((row[7] or 1) >= 1 and "%.0f" or "%.3f", tonumber(value) or 0) end
	return tostring(value or "")
end

local function drawPropertyControl(state, spec, item, bounds, colors)
	local row, kind = item.row, item.row[4]
	local control = { x1 = bounds.x1 + max(150, (bounds.x2 - bounds.x1) * 0.48), y1 = bounds.y1 + 8,
		x2 = bounds.x2 - 8, y2 = bounds.y2 - 8 }
	local action = { type = "property-control", row = row, rowIndex = item.rowIndex, kind = kind, control = control }
	if kind == "bool" then
		rect(control, spec.getValue(row) and colors.selected or colors.input)
		outline(control, colors.border, 1)
		label(valueText(spec, row), (control.x1 + control.x2) * 0.5, control.y1 + 10, 10, spec.getValue(row) and colors.accent or colors.muted, "oc")
	elseif kind == "number" then
		rect(control, colors.input); outline(control, colors.border, 1)
		local ratio = ((tonumber(spec.getValue(row)) or row[5]) - row[5]) / max(0.00001, row[6] - row[5])
		rect({ x1 = control.x1 + 3, y1 = control.y1 + 3, x2 = control.x1 + 3 + (control.x2 - control.x1 - 6) * clamp(ratio, 0, 1), y2 = control.y1 + 7 }, colors.accent)
		label(valueText(spec, row), (control.x1 + control.x2) * 0.5, control.y1 + 10, 10, colors.text, "oc")
	else
		rect(control, colors.input); outline(control, colors.border, 1)
		local suffix = kind == "enum" and "  [Choose]" or ""
		label(valueText(spec, row) .. suffix, control.x1 + 7, control.y1 + 10, 10, colors.text)
	end
	addHit(state, { x1 = control.x1, y1 = control.y1, x2 = control.x2, y2 = control.y2, id = "control:" .. item.id,
		action = action, tooltip = tostring(row[3]), accessibleLabel = tostring(row[3]) .. " " .. valueText(spec, row) }, false)
end

local function drawInspectorHeader(state, spec, pane, colors)
	local filterH, actionsH = 70, 66
	label(spec.tabName or "Properties", pane.x1 + 10, pane.y2 - 23, 13, colors.text)
	local search = { x1 = pane.x1 + 10, y1 = pane.y2 - 60, x2 = pane.x2 - 12, y2 = pane.y2 - 34 }
	rect(search, colors.input); outline(search, focused(state, "inspector:search") and colors.focus or colors.border,
		focused(state, "inspector:search") and 2 or 1)
	label(spec.search ~= "" and spec.search or "Search properties (Ctrl+F)", search.x1 + 7, search.y1 + 7, 10,
		spec.search ~= "" and colors.text or colors.muted)
	addHit(state, { x1 = search.x1, y1 = search.y1, x2 = search.x2, y2 = search.y2, id = "inspector:search",
		action = { type = "focus-property-search" }, tooltip = "Search properties", accessibleLabel = "Search properties" }, true)
	local actionsY1 = pane.y1 + 4
	local selected = spec.rows and spec.rows[spec.selectedRow]
	local x = pane.x1 + 8
	for _, def in ipairs({
		{ "Favorite", 64, "favorite-property", "Favorite selected property" },
		{ "Reset", 52, "reset-property", "Reset selected property" },
		{ "More", 48, "property-menu", "Saved value and shipping-default actions" },
	}) do
		local b = { x1 = x, y1 = actionsY1, x2 = x + def[2], y2 = actionsY1 + 26 }
		button(state, b, "inspector:" .. def[3], def[1], { type = def[3], row = selected }, colors, def[4], selected == nil)
		x = b.x2 + 4
	end
	local filter = { x1 = pane.x1 + 8, y1 = actionsY1 + 32, x2 = min(pane.x2 - 8, pane.x1 + 158), y2 = actionsY1 + 58 }
	button(state, filter, "filter:menu", "View: " .. tostring(spec.filterMode or "Basic"), { type = "filter-menu" }, colors,
		"Choose Basic, Advanced, All, Favorites, Recent, or Modified properties")
	return filterH, actionsH
end

local function drawInspectorItems(state, spec, viewport, items, colors)
	local scroll = state.panes.inspector.scroll
	beginClip(viewport)
	for _, item in ipairs(items) do
		local y2, y1 = viewport.y2 - item.offset + scroll, viewport.y2 - item.offset - item.height + scroll
		local virtual = { top = item.offset + item.height, bottom = item.offset }
		if item.kind == "group" then
			local action = { type = "toggle-property-group", group = item.id }
			addFocus(state, { id = "group:" .. item.id, action = action, pane = "inspector", virtualBounds = virtual,
				accessibleLabel = item.label .. " property group" })
			if y2 >= viewport.y1 and y1 <= viewport.y2 then
				local b = { x1 = viewport.x1 + 4, y1 = y1 + 1, x2 = viewport.x2 - 12, y2 = y2 - 1 }
				rect(b, colors.panelAlt)
				label((state.collapsed[item.id] and "+ " or "- ") .. item.label, b.x1 + 7, b.y1 + 9, 10, colors.muted)
				addHit(state, { x1 = b.x1, y1 = b.y1, x2 = b.x2, y2 = b.y2, id = "group:" .. item.id,
					action = action, tooltip = "Expand or collapse " .. item.label, accessibleLabel = item.label .. " property group" }, false)
				focusOutline(state, b, "group:" .. item.id, colors.focus)
			end
		else
			local rowId = "property:" .. item.id
			local action = { type = "focus-property", row = item.row, rowIndex = item.rowIndex }
			addFocus(state, { id = rowId, action = action, pane = "inspector", virtualBounds = virtual,
				row = item.row, rowIndex = item.rowIndex, accessibleLabel = tostring(item.row[3]) })
			if y2 >= viewport.y1 and y1 <= viewport.y2 then
				local b = { x1 = viewport.x1 + 4, y1 = y1 + 2, x2 = viewport.x2 - 12, y2 = y2 - 2 }
				local selected = item.rowIndex == spec.selectedRow
				rect(b, selected and colors.selected or (item.rowIndex % 2 == 0 and colors.rowAlt or colors.row))
				label(item.row[3], b.x1 + 9, b.y2 - 20, 10, colors.text)
				local source = spec.getSource and spec.getSource(item.row) or "personal"
				local flags = (spec.isModified and spec.isModified(item.row) and "modified / " or "")
					.. (spec.isEnforced and spec.isEnforced(item.row) and "locked / " or "") .. source
				label(flags, b.x1 + 9, b.y1 + 7, 8, colors.muted)
				drawPropertyControl(state, spec, item, b, colors)
				addHit(state, { x1 = b.x1, y1 = b.y1, x2 = b.x2, y2 = b.y2, id = rowId, action = action,
					tooltip = tostring(item.row[3]), accessibleLabel = tostring(item.row[3]) }, false)
				focusOutline(state, b, rowId, colors.focus)
			end
		end
	end
	endClip()
end

local function drawInspector(state, spec, colors)
	local pane = state.layout.inspector
	rect(pane, colors.panel); outline(pane, colors.border, 1)
	local headerH, actionsH = drawInspectorHeader(state, spec, pane, colors)
	local viewport = { x1 = pane.x1 + 4, y1 = pane.y1 + actionsH + 3, x2 = pane.x2 - 2, y2 = pane.y2 - headerH }
	state.inspectorViewport = viewport
	Workspace.SetInspectorKey(state, tostring(spec.inspectorKey or (tostring(spec.tabName or "") .. "|" .. tostring(spec.filterMode or ""))))
	local items, content = Workspace.PropertyItems(spec.rows, state.collapsed, spec.filterMode, spec.scopeLabels)
	Workspace.UpdatePane(state, "inspector", content, viewport.y2 - viewport.y1, viewport)
	if #items == 0 then label(spec.emptyText or "No properties match this view.", viewport.x1 + 10, viewport.y2 - 28, 11, colors.muted) end
	drawInspectorItems(state, spec, viewport, items, colors)
	drawScrollbar(state, "inspector", colors)
end

local function drawFooter(state, spec, colors)
	local pane, x = state.layout.footer, state.layout.footer.x1
	rect(pane, colors.panelAlt)
	local defs = {
		{ "Reset section", 94, "reset-section", "Reset the visible section" },
		{ "Reset all", 70, "reset-all", "Reset all controller UI settings" },
		{ "Save preset", 78, "save-preset", "Save selected component preset" },
		{ "Apply preset", 82, "apply-preset", "Apply selected component preset" },
	}
	for _, def in ipairs(defs) do
		local b = { x1 = x + 4, y1 = pane.y1 + 4, x2 = x + def[2], y2 = pane.y2 - 4 }
		button(state, b, "footer:" .. def[3], def[1], { type = def[3] }, colors, def[4])
		x = b.x2 + 4
	end
	label("Tab: focus  |  Arrows: navigate/adjust  |  F1: help", pane.x2 - 34, pane.y1 + 10, 9, colors.muted, "or")
	local resize = { x1 = pane.x2 - 22, y1 = pane.y1 + 1, x2 = pane.x2, y2 = pane.y1 + 23 }
	for line = 0, 2 do
		rect({ x1 = resize.x2 - 5 - line * 5, y1 = resize.y1 + 3, x2 = resize.x2 - 3, y2 = resize.y1 + 5 + line * 5 }, colors.accent)
	end
	addHit(state, { x1 = resize.x1, y1 = resize.y1, x2 = resize.x2, y2 = resize.y2, id = "footer:resize",
		action = { type = "resize-window" }, tooltip = "Resize editor window", accessibleLabel = "Resize editor window" }, false)
end

local function modalBounds(state, optionCount)
	local bounds = state.bounds
	local width, height = min(360, bounds.width - 40), min(bounds.height - 50, 52 + optionCount * 32)
	return { x1 = (bounds.x1 + bounds.x2 - width) * 0.5, y1 = (bounds.y1 + bounds.y2 - height) * 0.5,
		x2 = (bounds.x1 + bounds.x2 + width) * 0.5, y2 = (bounds.y1 + bounds.y2 + height) * 0.5 }
end

local function drawModal(state, colors)
	local modal = state.modal
	if not modal then return end
	local bounds = modalBounds(state, #modal.options)
	rect(state.bounds, { 0, 0, 0, 0.54 })
	rect(bounds, colors.panelAlt); outline(bounds, colors.focus, 2)
	label(modal.title, bounds.x1 + 12, bounds.y2 - 28, 13, colors.text)
	state.hits, state.focusItems = {}, {}
	for index, option in ipairs(modal.options) do
		local y2 = bounds.y2 - 42 - (index - 1) * 32
		local b = { x1 = bounds.x1 + 10, y1 = y2 - 28, x2 = bounds.x2 - 10, y2 = y2 }
		button(state, b, "modal:" .. index, option.label, { type = "modal-option", option = option, index = index }, colors,
			option.tooltip or option.label, option.disabled)
	end
	addHit(state, { x1 = state.bounds.x1, y1 = state.bounds.y1, x2 = state.bounds.x2, y2 = state.bounds.y2,
		id = "modal:backdrop", action = { type = "close-modal" }, accessibleLabel = "Close menu" }, false)
	-- Re-add option hits above the backdrop so they win reverse hit testing.
	local optionHits = {}
	for _, hit in ipairs(state.hits) do if hit.id and string.find(hit.id, "modal:", 1, true) == 1 and hit.id ~= "modal:backdrop" then optionHits[#optionHits + 1] = hit end end
	for _, hit in ipairs(optionHits) do state.hits[#state.hits + 1] = hit end
	ensureFocusExists(state)
end

local function drawHelp(state, colors)
	if not state.showHelp or state.modal then return end
	local options = {
		{ label = "Tab / Shift+Tab    Next / previous control", disabled = true },
		{ label = "Arrows              Navigate or adjust", disabled = true },
		{ label = "Page Up / Down      Scroll by one page", disabled = true },
		{ label = "Home / End          First / final control", disabled = true },
		{ label = "Enter / Space       Activate selected control", disabled = true },
		{ label = "Ctrl+F / Ctrl+S     Search / save", disabled = true },
		{ label = "Escape              Back or close editor", action = "close-help" },
	}
	Workspace.OpenModal(state, "Keyboard help", options, state.focusId)
end

local function drawTooltip(state, colors)
	if state.modal or not Spring or type(Spring.GetMouseState) ~= "function" then return end
	local x, y = Spring.GetMouseState()
	local hit = Workspace.FindHit(state, x, y)
	state.hovered = hit
	if not hit or not hit.tooltip then return end
	local width = clamp(#tostring(hit.tooltip) * 6.2 + 18, 120, 360)
	local tx = clamp(x + 14, state.bounds.x1 + 4, state.bounds.x2 - width - 4)
	local ty = clamp(y + 14, state.bounds.y1 + 4, state.bounds.y2 - 34)
	local b = { x1 = tx, y1 = ty, x2 = tx + width, y2 = ty + 28 }
	rect(b, colors.panelAlt); outline(b, colors.focus, 1); label(hit.tooltip, b.x1 + 8, b.y1 + 8, 10, colors.text)
end

function Workspace.Draw(state, spec)
	if not gl then return end
	Workspace.SetBounds(state, spec.bounds)
	state.hits, state.focusItems = {}, {}
	local colors = workspaceColors(spec.theme or {})
	rect(state.bounds, colors.background); outline(state.bounds, colors.focus, 1)
	drawHeader(state, spec, colors)
	drawToolbar(state, spec, colors)
	drawNav(state, spec, colors)
	drawPreview(state, spec, colors)
	drawInspector(state, spec, colors)
	drawFooter(state, spec, colors)
	ensureFocusExists(state)
	if state.showHelp then drawHelp(state, colors) end
	if state.modal then drawModal(state, colors) end
	drawTooltip(state, colors)
	return state.hits
end

function Workspace.OpenPropertyMenu(state, row, developer, hasSaved)
	local options = {
		{ label = "Favorite / unfavorite", action = "favorite", row = row },
		{ label = "Reset property", action = "reset", row = row },
		{ label = "Save current value", action = "save-value", row = row },
		{ label = "Apply saved value", action = "apply-value", row = row, disabled = not hasSaved },
	}
	if developer then options[#options + 1] = { label = "Toggle shipping lock", action = "toggle-enforcement", row = row } end
	Workspace.OpenModal(state, tostring(row and row[3] or "Property actions"), options, state.focusId)
end

function Workspace.OpenAlignmentMenu(state)
	Workspace.OpenModal(state, "Alignment and distribution", {
		{ label = "Align left", action = "align-left" }, { label = "Center horizontally", action = "align-hcenter" },
		{ label = "Align right", action = "align-right" }, { label = "Align bottom", action = "align-bottom" },
		{ label = "Center vertically", action = "align-vcenter" }, { label = "Align top", action = "align-top" },
		{ label = "Distribute horizontally", action = "distribute-horizontal" },
		{ label = "Distribute vertically", action = "distribute-vertical" },
	}, state.focusId)
end

function Workspace.OpenEnumMenu(state, row, options, value)
	local entries = {}
	for _, option in ipairs(options or {}) do entries[#entries + 1] = { label = (option == value and "Selected: " or "") .. tostring(option),
		action = "set-enum", row = row, value = option } end
	Workspace.OpenModal(state, tostring(row and row[3] or "Choose value"), entries, state.focusId)
end

function Workspace.OpenFilterMenu(state, current)
	local options = {}
	for _, mode in ipairs({ "Basic", "Advanced", "All", "Favorites", "Recent", "Modified" }) do
		options[#options + 1] = { label = (mode == current and "Selected: " or "") .. mode, action = "set-filter", value = mode }
	end
	Workspace.OpenModal(state, "Property view", options, state.focusId)
end

Workspace.Clamp = clamp
Workspace.Inside = inside

return Workspace
