
HS = HS or {}
HS.select = HS.select or {}

local Sel = HS.select

local function hsShared()
	return (shared and shared.hs) or nil
end

local function matchView(sh)
	if type(sh) ~= "table" then return nil end
	return type(sh.match) == "table" and sh.match or nil
end

local function playersView(sh)
	if type(sh) ~= "table" then return nil end
	return type(sh.players) == "table" and sh.players or nil
end

local function abilitiesView(sh)
	if type(sh) ~= "table" then return nil end
	return type(sh.abilities) == "table" and sh.abilities or nil
end

local function metaView(sh)
	if type(sh) ~= "table" then return nil end
	return type(sh.meta) == "table" and sh.meta or nil
end

local function ensureTable(parent, key)
	local t = parent[key]
	if t == nil then
		t = {}
		parent[key] = t
	end
	return t
end

function Sel.shared()
	return hsShared()
end

function Sel.localPlayerId(ctx)
	local engine = (ctx and ctx.engine) or HS.engine
	return engine and engine.localPlayerId and engine.localPlayerId() or 0
end

function Sel.localTeam(sh, localId)
	local players = playersView(sh)
	if not players or not players.teamOf then return 0 end
	return players.teamOf[localId] or 0
end

function Sel.localOut(sh, localId)
	local players = playersView(sh)
	if not players or not players.outOf then return false end
	return players.outOf[localId] == true
end

function Sel.secondsLeft(sh, now)
	local m = matchView(sh)
	if not m then return 0 end
	local endt = tonumber(m.phaseEndsAt) or 0
	if endt <= 0 then return 0 end
	return math.max(0, endt - (tonumber(now) or 0))
end

function Sel.phaseKey(phase)
	if phase == HS.const.PHASE_SETUP then return "hs.phase.setup" end
	if phase == HS.const.PHASE_HIDING then return "hs.phase.hiding" end
	if phase == HS.const.PHASE_SEEKING then return "hs.phase.seeking" end
	if phase == HS.const.PHASE_INTERMISSION then return "hs.phase.intermission" end
	return "hs.phase.setup"
end

function Sel.roleKey(teamId)
	if teamId == HS.const.TEAM_SEEKERS then return "hs.role.seeker" end
	if teamId == HS.const.TEAM_HIDERS then return "hs.role.hider" end
	return "hs.role.spectator"
end

function Sel.teamNameKey(teamId)
	if teamId == HS.const.TEAM_SEEKERS then return "hs.team.seekers" end
	if teamId == HS.const.TEAM_HIDERS then return "hs.team.hiders" end
	return "hs.role.spectator"
end

function Sel.matchVm(ctx, sh)
	ctx = ctx or (HS.ctx and HS.ctx.get and HS.ctx.get()) or { cache = {} }
	ctx.cache = ctx.cache or {}

	local vm = ensureTable(ctx.cache, "_vmMatch")
	local localVm = ensureTable(vm, "me")

	local localNow = tonumber(ctx.now) or (HS.engine and HS.engine.now and HS.engine.now()) or 0
	local now = localNow
	local m = matchView(sh)
	local players = playersView(sh)
	local abilitiesRoot = abilitiesView(sh)
	local meta = metaView(sh)
	local serverNowRaw = meta and meta.serverNow
	if ctx.side == "client" then
		local tsAt = tonumber(ctx.cache._timeSyncLastAt)
		local hasFreshTimeSync = tsAt ~= nil and (localNow - tsAt) <= 8.0
		if hasFreshTimeSync then
			now = localNow + (tonumber(ctx.cache._serverTimeOffset) or 0)
		elseif serverNowRaw ~= nil then
			local serverNow = tonumber(serverNowRaw) or 0
			local sample = ctx.cache._serverNowSample
			if sample == nil or math.abs(serverNow - sample) > 0.0001 then
				ctx.cache._serverNowSample = serverNow
				local newOffset = serverNow - localNow
				local prevOffset = ctx.cache._serverTimeOffset
				if prevOffset == nil then
					ctx.cache._serverTimeOffset = newOffset
				else
					ctx.cache._serverTimeOffset = prevOffset * 0.9 + newOffset * 0.1
				end
			end
			now = localNow + (tonumber(ctx.cache._serverTimeOffset) or 0)
		end
	end
	local localId = Sel.localPlayerId(ctx)
	local team = Sel.localTeam(sh, localId)
	local out = Sel.localOut(sh, localId)

	vm.ready = (sh ~= nil)
	vm.now = now
	vm.phase = (m and m.phase) or HS.const.PHASE_SETUP
	vm.phaseEndsAt = (m and tonumber(m.phaseEndsAt)) or 0
	vm.timeLeft = (vm.phaseEndsAt > 0) and math.max(0, vm.phaseEndsAt - now) or 0
	vm.round = (m and tonumber(m.round)) or 0
	vm.roundsToPlay = (sh and sh.settings and tonumber(sh.settings.roundsToPlay)) or 0
	vm.scoreSeekers = (m and tonumber(m.scoreSeekers)) or 0
	vm.scoreHiders = (m and tonumber(m.scoreHiders)) or 0
	vm.seekersCount = (m and tonumber(m.seekersCount)) or 0
	vm.hidersRemaining = (m and tonumber(m.hidersRemaining)) or 0
	vm.lastWinner = (m and tostring(m.lastWinner or "")) or ""
	vm.matchActive = (m and m.matchActive == true) or false

	vm.phaseLabel = HS.t(Sel.phaseKey(vm.phase))
	vm.roleLabel = HS.t(Sel.roleKey(team))

	localVm.id = localId
	localVm.team = team
	localVm.out = out
	localVm.spectating = out or team == 0
	localVm.isHost = (HS.engine and HS.engine.isPlayerValid and HS.engine.isPlayerHost and HS.engine.isPlayerValid(localId) and HS.engine.isPlayerHost(localId)) or false

	vm.settings = (sh and sh.settings) or {}
	vm.uiHints = (sh and sh.uiHints) or {}
	vm.teamOf = players and players.teamOf or nil
	vm.outOf = players and players.outOf or nil
	vm.readyOf = players and players.readyOf or nil

	local abilities = ensureTable(vm, "abilities")
	local defs = (HS.abilities and HS.abilities.list and HS.abilities.list()) or {}
	for id in pairs(abilities) do
		if not (HS.abilities and HS.abilities.def and HS.abilities.def(id)) then
			abilities[id] = nil
		end
	end

	local readyMap = abilitiesRoot and abilitiesRoot.readyAt or nil
	local armedMap = abilitiesRoot and abilitiesRoot.armedUntil or nil
	for i = 1, #defs do
		local def = defs[i]
		local id = def and def.id
		if id then
			local st = ensureTable(abilities, id)
			local perReady = readyMap and readyMap[id]
			local perArmed = armedMap and armedMap[id]
			st.readyAt = (perReady and tonumber(perReady[localId])) or 0
			st.armedUntil = (perArmed and tonumber(perArmed[localId])) or 0
		end
	end
	return vm
end
