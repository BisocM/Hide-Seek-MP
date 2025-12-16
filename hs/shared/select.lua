
HS = HS or {}
HS.select = HS.select or {}

local Sel = HS.select

local function hsShared()
	return (shared and shared.hs) or nil
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
	if not sh or not sh.teamOf then return 0 end
	return sh.teamOf[localId] or 0
end

function Sel.localOut(sh, localId)
	if not sh or not sh.outOf then return false end
	return sh.outOf[localId] == true
end

function Sel.secondsLeft(sh, now)
	if not sh then return 0 end
	local endt = tonumber(sh.phaseEndsAt) or 0
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
	if ctx.side == "client" then
		local tsAt = tonumber(ctx.cache._timeSyncLastAt)
		local hasFreshTimeSync = tsAt ~= nil and (localNow - tsAt) <= 8.0
		if hasFreshTimeSync then
			now = localNow + (tonumber(ctx.cache._serverTimeOffset) or 0)
		elseif sh and sh.serverNow ~= nil then
			local serverNow = tonumber(sh.serverNow) or 0
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
	vm.phase = (sh and sh.phase) or HS.const.PHASE_SETUP
	vm.phaseEndsAt = (sh and tonumber(sh.phaseEndsAt)) or 0
	vm.timeLeft = (vm.phaseEndsAt > 0) and math.max(0, vm.phaseEndsAt - now) or 0
	vm.round = (sh and tonumber(sh.round)) or 0
	vm.roundsToPlay = (sh and sh.settings and tonumber(sh.settings.roundsToPlay)) or 0
	vm.scoreSeekers = (sh and tonumber(sh.scoreSeekers)) or 0
	vm.scoreHiders = (sh and tonumber(sh.scoreHiders)) or 0
	vm.seekersCount = (sh and tonumber(sh.seekersCount)) or 0
	vm.hidersRemaining = (sh and tonumber(sh.hidersRemaining)) or 0
	vm.lastWinner = (sh and tostring(sh.lastWinner or "")) or ""
	vm.matchActive = (sh and sh.matchActive == true) or false

	vm.phaseLabel = HS.t(Sel.phaseKey(vm.phase))
	vm.roleLabel = HS.t(Sel.roleKey(team))

	localVm.id = localId
	localVm.team = team
	localVm.out = out
	localVm.spectating = out or team == 0
	localVm.isHost = (type(IsPlayerHost) == "function" and type(IsPlayerValid) == "function" and IsPlayerValid(localId) and IsPlayerHost(localId)) or false

	vm.settings = (sh and sh.settings) or {}
	vm.teamOf = (sh and sh.teamOf) or nil
	vm.outOf = (sh and sh.outOf) or nil
	vm.readyOf = (sh and sh.readyOf) or nil

	local abilities = ensureTable(vm, "abilities")
	local defs = (HS.abilities and HS.abilities.list and HS.abilities.list()) or {}
	for id in pairs(abilities) do
		if not (HS.abilities and HS.abilities.def and HS.abilities.def(id)) then
			abilities[id] = nil
		end
	end

	local readyMap = sh and sh.abilityReadyAt or nil
	local armedMap = sh and sh.abilityArmedUntil or nil
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
