--------------------------------------------------------------------------------
-- Controller UI Authoring native modal input state
--------------------------------------------------------------------------------

local Input = {}

function Input.New()
	return { open = false, pointer = nil, buttons = {}, keys = {}, composition = "", generation = 0 }
end

function Input.Open(state)
	Input.Clear(state)
	state.open = true
	state.generation = (state.generation or 0) + 1
	return state.generation
end

function Input.Clear(state)
	state.pointer = nil
	state.buttons = {}
	state.keys = {}
	state.composition = ""
end

function Input.Close(state)
	Input.Clear(state)
	state.open = false
end

function Input.Press(state, button, x, y)
	if not state.open then return false end
	state.buttons[button] = true
	state.pressX, state.pressY = x, y
	return true
end

function Input.Capture(state, kind, data, button, x, y)
	if not state.open then return false end
	state.pointer = { kind = kind, data = data or {}, button = button, startX = x, startY = y, x = x, y = y }
	return state.pointer
end

function Input.Move(state, x, y)
	local pointer = state.pointer
	if not pointer then return nil end
	pointer.x, pointer.y = x, y
	return pointer
end

function Input.Release(state, button)
	if not state.open then return false end
	state.buttons[button] = nil
	local pointer = state.pointer
	if pointer and (pointer.button == nil or pointer.button == button) then state.pointer = nil end
	return pointer or true
end

function Input.Pointer(state)
	return state.pointer
end

function Input.KeyDown(state, key)
	if not state.open then return false end
	state.keys[key] = true
	return true
end

function Input.KeyUp(state, key)
	state.keys[key] = nil
	return state.open
end

function Input.SetComposition(state, value)
	state.composition = tostring(value or "")
	return state.composition
end

function Input.LostFocus(state)
	Input.Clear(state)
	return state.open
end

return Input
