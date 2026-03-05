HS = HS or {}
HS.infra = HS.infra or {}
HS.infra.playerTools = HS.infra.playerTools or {}

local T = HS.infra.playerTools

local function isFn(f)
	return type(f) == "function"
end

function T.setEnabled(playerId, toolId, enabled)
	enabled = enabled == true
	playerId = tonumber(playerId) or 0
	toolId = tostring(toolId or "")
	if toolId == "" then
		return false
	end

	if isFn(SetToolEnabled) then
		local ok = pcall(SetToolEnabled, toolId, enabled, playerId)
		if ok then return true end
		ok = pcall(SetToolEnabled, toolId, playerId, enabled)
		if ok then return true end
	end

	if isFn(SetBool) then
		local key = string.format("game.tool.%s.enabled", toolId)
		return pcall(SetBool, key, enabled) == true
	end

	return false
end

function T.isEnabled(playerId, toolId, default)
	playerId = tonumber(playerId) or 0
	toolId = tostring(toolId or "")
	if toolId == "" then
		return default == true
	end

	if isFn(IsToolEnabled) then
		local ok, v = pcall(IsToolEnabled, toolId, playerId)
		if ok then return v == true end
	end

	if isFn(GetBool) then
		local key = string.format("game.tool.%s.enabled", toolId)
		local ok, v = pcall(GetBool, key)
		if ok then return v == true end
	end

	return default == true
end

function T.getEquipped(playerId)
	playerId = tonumber(playerId) or 0
	if playerId <= 0 or not isFn(GetPlayerTool) then
		return ""
	end
	local ok, v = pcall(GetPlayerTool, playerId)
	if not ok then
		return ""
	end
	return tostring(v or "")
end

function T.setEquipped(playerId, toolId)
	playerId = tonumber(playerId) or 0
	toolId = tostring(toolId or "")
	if playerId <= 0 or not isFn(SetPlayerTool) then
		return false
	end
	local ok = pcall(SetPlayerTool, toolId, playerId)
	if ok then return true end
	ok = pcall(SetPlayerTool, playerId, toolId)
	return ok == true
end
