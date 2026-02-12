HS = HS or {}
HS.input = HS.input or {}

local I = HS.input

I.actions = I.actions or {}
I.actions.tag = I.actions.tag or "interact"

I.keys = I.keys or {}
I.keys.abilityDash = I.keys.abilityDash or "q"
I.keys.abilitySuperjump = I.keys.abilitySuperjump or "f"
I.keys.abilitySlot3 = I.keys.abilitySlot3 or "x"
I.keys.abilitySlot4 = I.keys.abilitySlot4 or "c"
I.keys.abilitySlot5 = I.keys.abilitySlot5 or "v"
I.keys.adminMenu = I.keys.adminMenu or "f6"

function I.pressed(actionName)
	local a = I.actions[actionName] or actionName
	return HS.engine.inputPressed(a)
end

function I.keyPressed(keyName)
	local expected = I.keys[keyName] or keyName
	expected = string.lower(tostring(expected or ""))
	if expected == "" then return false end
	local key = string.lower(HS.engine.lastPressedKey() or "")
	return key == expected
end
