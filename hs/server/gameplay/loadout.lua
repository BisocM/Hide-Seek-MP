HS = HS or {}
HS.srv = HS.srv or {}
HS.srv.loadout = HS.srv.loadout or {}

local M = HS.srv.loadout

local function isFn(f) return type(f) == "function" end

local function safeSetToolEnabled(toolId, enabled, playerId)
	enabled = enabled == true
	playerId = tonumber(playerId) or 0
	if isFn(SetToolEnabled) then
		-- Most builds: (toolId, enabled, playerId). Some older/variant builds may swap args.
		local ok = pcall(SetToolEnabled, tostring(toolId or ""), enabled, playerId)
		if ok then return true end
		ok = pcall(SetToolEnabled, tostring(toolId or ""), playerId, enabled)
		if ok then return true end
	end
	-- Fallback: global registry (not per-player). Better than nothing on older builds.
	if isFn(SetBool) then
		local key = string.format("game.tool.%s.enabled", tostring(toolId or ""))
		return pcall(SetBool, key, enabled) == true
	end
	return false
end

local function safeIsToolEnabled(toolId, playerId, default)
	playerId = tonumber(playerId) or 0
	if isFn(IsToolEnabled) then
		local ok, v = pcall(IsToolEnabled, tostring(toolId or ""), playerId)
		if ok then return v == true end
	end
	if isFn(GetBool) then
		local key = string.format("game.tool.%s.enabled", tostring(toolId or ""))
		local ok, v = pcall(GetBool, key)
		if ok then return v == true end
	end
	return default == true
end

local function safeGetPlayerTool(playerId)
	playerId = tonumber(playerId) or 0
	if isFn(GetPlayerTool) then
		local ok, v = pcall(GetPlayerTool, playerId)
		if ok and type(v) == "string" then
			return v
		end
	end
	return ""
end

local function safeSetPlayerTool(toolId, playerId)
	playerId = tonumber(playerId) or 0
	if not isFn(SetPlayerTool) then return false end
	-- Most builds: (toolId, playerId). Some variant builds: (playerId, toolId).
	local ok = pcall(SetPlayerTool, tostring(toolId or ""), playerId)
	if ok then return true end
	ok = pcall(SetPlayerTool, playerId, tostring(toolId or ""))
	return ok == true
end

local function assignFor(loadout, toolId)
	if not loadout then return 0 end
	local a = loadout.assign
	local v = (type(a) == "table") and a[tostring(toolId or "")] or nil
	if v == nil and HS.loadout and HS.loadout.defaultAssignFor then
		v = HS.loadout.defaultAssignFor(toolId)
	end
	if HS.loadout and HS.loadout.clampAssign then
		return HS.loadout.clampAssign(v)
	end
	return math.floor(tonumber(v) or 0)
end

local function allowedFor(loadout, toolId, teamId, spectating)
	if spectating then return false end
	if not (HS.loadout and HS.loadout.allowed) then return false end
	return HS.loadout.allowed(assignFor(loadout, toolId), teamId) == true
end

local function firstAllowedTool(loadout, teamId, spectating)
	if spectating then return "" end
	local tools = (loadout and type(loadout.tools) == "table") and loadout.tools or {}
	for i = 1, #tools do
		local id = tostring(tools[i] or "")
		if id ~= "" and allowedFor(loadout, id, teamId, spectating) then
			return id
		end
	end
	return ""
end

local function ensureCache(state)
	state._loadoutCache = state._loadoutCache or {
		active = false,
		toolsKey = "",
		origEnabled = {}, -- pid -> toolId -> bool
		applied = {}, -- pid -> toolId -> bool
	}
	return state._loadoutCache
end

local function restoreAll(state, cache)
	cache = cache or ensureCache(state)
	for pid, perTool in pairs(cache.origEnabled or {}) do
		pid = tonumber(pid) or 0
		if pid ~= 0 and isFn(IsPlayerValid) and IsPlayerValid(pid) then
			for toolId, orig in pairs(perTool or {}) do
				safeSetToolEnabled(toolId, orig == true, pid)
			end
		end
	end
	cache.active = false
	cache.toolsKey = ""
	cache.origEnabled = {}
	cache.applied = {}
end

function M.invalidate(state)
	if not state then return end
	local cache = ensureCache(state)
	if cache.active then
		restoreAll(state, cache)
	end
end

function M.tick(state, _dt)
	if not state or not state.settings then return end

	local loadout = state.settings.loadout
	local enabled = (type(loadout) == "table") and (loadout.enabled == true)
	local cache = ensureCache(state)

	if not enabled then
		if cache.active then
			restoreAll(state, cache)
		end
		return
	end

	-- Ensure we have a tool list when enforcement is enabled.
	if type(loadout.tools) ~= "table" or #loadout.tools == 0 then
		if HS.loadout and HS.loadout.discoverTools then
			loadout.tools = HS.loadout.discoverTools()
		else
			loadout.tools = {}
		end
		if HS.loadout and HS.loadout.normalize then
			state.settings.loadout = HS.loadout.normalize(loadout, state.settings.loadout)
			loadout = state.settings.loadout
		end
		state._settingsCopy = nil
		HS.state.snapshot.syncFromSource(state)
	end

	local toolsKey = ""
	if type(loadout.tools) == "table" and #loadout.tools > 0 then
		toolsKey = table.concat(loadout.tools, ",")
	end

	if cache.active and cache.toolsKey ~= toolsKey then
		-- Tool list changed: restore old state first so removed tools aren't left in a modified state.
		restoreAll(state, cache)
	end

	cache.active = true
	cache.toolsKey = toolsKey
	cache.origEnabled = cache.origEnabled or {}
	cache.applied = cache.applied or {}

	local tools = loadout.tools or {}

	for _, pid in ipairs(HS.util.getPlayersSorted()) do
		if isFn(IsPlayerValid) and IsPlayerValid(pid) then
			local p = state.players and state.players[pid] or nil
			local team = p and tonumber(p.team) or 0
			local spectating = (not p) or p.out == true or team == 0

			cache.origEnabled[pid] = cache.origEnabled[pid] or {}
			cache.applied[pid] = cache.applied[pid] or {}
			local orig = cache.origEnabled[pid]
			local applied = cache.applied[pid]

			local fallback = ""
			if not spectating then
				fallback = firstAllowedTool(loadout, team, spectating)
			end

			for i = 1, #tools do
				local toolId = tostring(tools[i] or "")
				if toolId ~= "" then
					local desired = allowedFor(loadout, toolId, team, spectating)
					if orig[toolId] == nil then
						orig[toolId] = safeIsToolEnabled(toolId, pid, true)
					end
					if applied[toolId] ~= desired then
						if safeSetToolEnabled(toolId, desired, pid) then
							applied[toolId] = desired
						end
					end
				end
			end

			-- Teardown can keep the currently equipped tool even when it becomes disabled.
			-- Also, in some builds the "current tool" query isn't available, so clear explicitly when
			-- there are no allowed tools at all (e.g. "Disable all").
			local cur = safeGetPlayerTool(pid)
			if fallback == "" then
				safeSetPlayerTool("none", pid)
				safeSetPlayerTool("", pid)
			elseif cur ~= "" and not allowedFor(loadout, cur, team, spectating) then
				safeSetPlayerTool(fallback, pid)
			end
		end
	end
end
