HS = HS or {}
HS.infra = HS.infra or {}
HS.infra.loadout = HS.infra.loadout or {}

local L = HS.infra.loadout

local function toolApi()
	return HS.infra and HS.infra.playerTools or nil
end

local function safeSetToolEnabled(toolId, enabled, playerId)
	local api = toolApi()
	if api and api.setEnabled then
		return api.setEnabled(playerId, toolId, enabled) == true
	end
	return false
end

local function safeIsToolEnabled(toolId, playerId, default)
	local api = toolApi()
	if api and api.isEnabled then
		return api.isEnabled(playerId, toolId, default)
	end
	return default == true
end

local function safeGetPlayerTool(playerId)
	local api = toolApi()
	if api and api.getEquipped then
		return tostring(api.getEquipped(playerId) or "")
	end
	return ""
end

local function safeSetPlayerTool(toolId, playerId)
	local api = toolApi()
	if api and api.setEquipped then
		return api.setEquipped(playerId, toolId) == true
	end
	return false
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
		origEnabled = {},
		applied = {},
	}
	return state._loadoutCache
end

local function restoreAll(state, cache)
	cache = cache or ensureCache(state)
	for pid, perTool in pairs(cache.origEnabled or {}) do
		pid = tonumber(pid) or 0
		if pid ~= 0 and HS.infra.players and HS.infra.players.isValid and HS.infra.players.isValid(pid) then
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

function L.reset(state)
	if type(state) ~= "table" then return end
	local cache = ensureCache(state)
	if cache.active then
		restoreAll(state, cache)
	end
end

function L.tick(state)
	if type(state) ~= "table" or type(state.settings) ~= "table" then return end

	local loadout = state.settings.loadout
	local enabled = (type(loadout) == "table") and (loadout.enabled == true)
	local cache = ensureCache(state)

	if not enabled then
		if cache.active then
			restoreAll(state, cache)
		end
		return
	end

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
	end

	local toolsKey = ""
	if type(loadout.tools) == "table" and #loadout.tools > 0 then
		toolsKey = table.concat(loadout.tools, ",")
	end

	if cache.active and cache.toolsKey ~= toolsKey then
		restoreAll(state, cache)
	end

	cache.active = true
	cache.toolsKey = toolsKey
	cache.origEnabled = cache.origEnabled or {}
	cache.applied = cache.applied or {}

	local tools = loadout.tools or {}
	local ids = (HS.infra.players and HS.infra.players.listSorted and HS.infra.players.listSorted()) or {}
	local mimicId = ((HS.abilities and HS.abilities.ids and HS.abilities.ids.mimicProp) or "mimic_prop")
	local now = (HS.infra and HS.infra.clock and HS.infra.clock.now and HS.infra.clock.now()) or 0

	for i = 1, #ids do
		local pid = tonumber(ids[i]) or 0
		if pid > 0 and HS.infra.players and HS.infra.players.isValid and HS.infra.players.isValid(pid) then
			local p = state.players and state.players[pid] or nil
			local team = p and tonumber(p.team) or 0
			local spectating = (not p) or p.out == true or team == 0
			local mimicActive = false
			if p and type(p.abilities) == "table" then
				local ab = p.abilities[mimicId]
				local untilAt = tonumber(ab and ab.armedUntil) or 0
				mimicActive = untilAt > now
			end
			if mimicActive then
				spectating = true
			end

			cache.origEnabled[pid] = cache.origEnabled[pid] or {}
			cache.applied[pid] = cache.applied[pid] or {}
			local orig = cache.origEnabled[pid]
			local applied = cache.applied[pid]

			local fallback = ""
			if not spectating then
				fallback = firstAllowedTool(loadout, team, spectating)
			end

			for j = 1, #tools do
				local toolId = tostring(tools[j] or "")
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
