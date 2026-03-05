HS = HS or {}
HS.app = HS.app or {}
HS.app.serverRuntime = HS.app.serverRuntime or {}

local R = HS.app.serverRuntime

local function logWarn(msg, data)
	if HS.log and HS.log.warn then
		HS.log.warn(msg, data)
	end
end

local function logInfo(msg, data)
	if HS.log and HS.log.info then
		HS.log.info(msg, data)
	end
end

local function now()
	if HS.util and HS.util.time and HS.util.time.now then
		return HS.util.time.now()
	end
	return HS.infra and HS.infra.clock and HS.infra.clock.now and HS.infra.clock.now() or 0
end

local function appendAll(dst, src)
	if HS.util and HS.util.table and HS.util.table.appendAll then
		HS.util.table.appendAll(dst, src)
		return
	end
	for i = 1, #(src or {}) do
		dst[#dst + 1] = src[i]
	end
end

local function mergeFields(base, extra)
	if HS.util and HS.util.table and HS.util.table.mergeFields then
		return HS.util.table.mergeFields(base, extra)
	end
	local out = {}
	local b = type(base) == "table" and base or {}
	local e = type(extra) == "table" and extra or {}
	for k, v in pairs(b) do
		out[k] = v
	end
	for k, v in pairs(e) do
		out[k] = v
	end
	return out
end

local function roundFields(state)
	local stats = {}
	local internal = HS.domain and HS.domain.reducers and HS.domain.reducers.internal
	if internal and internal.roundFormationStats then
		stats = internal.roundFormationStats(state) or {}
	end
	return {
		phase = tostring(state and state.phase or ""),
		setupState = tostring(state and state.setupState or ""),
		round = tonumber(state and state.round) or 0,
		matchActive = (state and state.matchActive) == true,
		players = tonumber(stats.players) or 0,
		assignedSeekers = tonumber(stats.assignedSeekers) or 0,
		assignedHiders = tonumber(stats.assignedHiders) or 0,
		assignedNone = tonumber(stats.assignedNone) or 0,
		baseSeekers = tonumber(stats.baseSeekers) or 0,
		baseHiders = tonumber(stats.baseHiders) or 0,
		baseNone = tonumber(stats.baseNone) or 0,
		aliveSeekers = tonumber(stats.aliveSeekers) or 0,
		aliveHiders = tonumber(stats.aliveHiders) or 0,
		outSeekers = tonumber(stats.outSeekers) or 0,
		outHiders = tonumber(stats.outHiders) or 0,
		outUnassigned = tonumber(stats.outUnassigned) or 0,
		late = tonumber(stats.late) or 0,
		ready = tonumber(stats.ready) or 0,
		maxTeamDiff = tonumber(stats.maxTeamDiff) or 0,
	}
end

local function eventToastKey(ev)
	local payload = type(ev) == "table" and type(ev.payload) == "table" and ev.payload or nil
	local message = payload and payload.message or nil
	if type(message) == "table" then
		return tostring(message.key or "")
	end
	if type(message) == "string" then
		return message
	end
	return ""
end

local function hasToast(events, key)
	local types = HS.contracts and HS.contracts.eventTypes
	local toastType = (types and types.TOAST) or "ui.toast"
	for i = 1, #(events or {}) do
		local ev = events[i]
		if type(ev) == "table" and ev.type == toastType and eventToastKey(ev) == key then
			return true
		end
	end
	return false
end

local function findEvent(events, eventType)
	for i = 1, #(events or {}) do
		local ev = events[i]
		if type(ev) == "table" and ev.type == eventType then
			return ev
		end
	end
	return nil
end

local function buildAbilityDefs()
	local defs = {}
	local list = (HS.abilities and HS.abilities.list and HS.abilities.list()) or {}
	for i = 1, #list do
		local d = list[i]
		if type(d) == "table" and d.id then
			defs[tostring(d.id)] = HS.util.deepcopy(d)
		end
	end
	return defs
end

local function playerNamesMap(state)
	local out = {}
	local ids = HS.domain.model.sortedPlayerIds(state)
	for i = 1, #ids do
		local pid = ids[i]
		out[pid] = HS.infra.players.name(pid)
	end
	return out
end

local function emitClientEvent(event)
	if type(event) ~= "table" then return end
	if not (HS.infra and HS.infra.events and HS.infra.events.emit) then return end
	HS.infra.events.emit(tonumber(event.target) or 0, event.type, event.payload)
end

local function handleEvents(state, prevState, events, frameNow)
	for i = 1, #(events or {}) do
		local ev = events[i]
		if type(ev) == "table" and type(ev.type) == "string" then
			if string.sub(ev.type, 1, 4) == "srv." then
				if HS.infra and HS.infra.effects and HS.infra.effects.handleServerEvent then
					HS.infra.effects.handleServerEvent(state, prevState, ev, frameNow)
				end
			else
				emitClientEvent(ev)
			end
		end
	end
end

local function normalizeIncomingEnvelope(env, state)
	local T = HS.contracts and HS.contracts.commandTypes
	if not T then return env end

	env.payload = type(env.payload) == "table" and env.payload or {}
	local p = env.payload

	if env.type == T.START_MATCH then
		local inSettings = type(p.settings) == "table" and p.settings or p
		local base = (state and state.settings) or ((HS.settings and HS.settings.defaults and HS.settings.defaults()) or {})
		local normalized = (HS.settings and HS.settings.normalize and HS.settings.normalize(inSettings, base)) or inSettings
		if HS.loadout and HS.loadout.normalize then
			normalized.loadout = HS.loadout.normalize(inSettings.loadout or {}, normalized.loadout)
		end
		env.payload = { settings = normalized }
	elseif env.type == T.UPDATE_LOADOUT then
		local lo = p.loadout or p
		if HS.loadout and HS.loadout.normalize then
			lo = HS.loadout.normalize(lo, state and state.settings and state.settings.loadout)
		end
		env.payload = { loadout = lo }
	elseif env.type == T.ABILITY then
		local abilityId = tostring(p.abilityId or "")
		local eventName = tostring(p.event or "use")
		local mimicId = (HS.abilities and HS.abilities.ids and HS.abilities.ids.mimicProp) or "mimic_prop"
		env.payload = {
			abilityId = abilityId,
			event = eventName,
			mimicBodyId = math.floor(tonumber(p.mimicBodyId) or 0),
			mimicReason = tostring(p.mimicReason or ""),
		}
		if abilityId == mimicId and eventName == "use" and HS.infra and HS.infra.mimic and HS.infra.mimic.selectForCommand then
			local phase = tostring(state and state.phase or "")
			local playerState = state and state.players and state.players[env.playerId] or nil
			local canProbe = (phase == HS.const.PHASE_HIDING or phase == HS.const.PHASE_SEEKING)
				and playerState and playerState.team == HS.const.TEAM_HIDERS and playerState.out ~= true
			if canProbe then
				if (tonumber(env.payload.mimicBodyId) or 0) <= 0 then
					local sel = HS.infra.mimic.selectForCommand(state, env.playerId)
					env.payload.mimicBodyId = tonumber(sel and sel.bodyId) or 0
					env.payload.mimicReason = tostring(sel and sel.reason or "")
				end
			else
				env.payload.mimicBodyId = 0
				env.payload.mimicReason = "phase_or_role"
			end
		end
	elseif env.type == T.TIME_SYNC then
		env.payload = {
			seq = tonumber(p.seq) or 0,
			clientSentAt = tonumber(p.clientSentAt) or 0,
		}
	elseif env.type == T.TEAM_JOIN then
		env.payload = {
			teamId = math.floor(tonumber(p.teamId) or 0),
		}
	elseif env.type == T.REQUEST_TAG then
		local range = tonumber(state and state.settings and state.settings.tagRangeMeters) or 4.0
		local targetId = 0
		if HS.infra and HS.infra.targeting and HS.infra.targeting.findTagTarget then
			targetId = HS.infra.targeting.findTagTarget(state, env.playerId, range)
		end
		env.payload = { targetId = tonumber(targetId) or 0 }
	end

	return env
end

local function syncRoster(state, frameNow)
	local events = {}
	local players = HS.infra and HS.infra.players
	if not (players and players.listSorted) then
		return state, events
	end

	local ids = players.listSorted()
	local present = {}
	for i = 1, #ids do
		local pid = tonumber(ids[i]) or 0
		if pid > 0 then
			present[pid] = true
		end
	end

	local added = {}
	for i = 1, #ids do
		local pid = tonumber(ids[i]) or 0
		if pid > 0 and state.players[pid] == nil then
			added[#added + 1] = pid
		end
	end

	local removed = {}
	for _, pid in ipairs(HS.domain.model.sortedPlayerIds(state)) do
		if not present[pid] then
			removed[#removed + 1] = pid
		end
	end

	if #added == 0 and #removed == 0 then
		return state, events
	end

	local nextState, rosterEvents = HS.domain.reducers.command.reduce(state, {
		type = "__roster_sync",
		playerId = 0,
		payload = {
			added = added,
			removed = removed,
			now = frameNow,
		},
	}, { now = frameNow })

	appendAll(events, rosterEvents)
	return nextState, events
end

local function processCommands(state, frameNow)
	local allEvents = {}
	local validate = HS.contracts and HS.contracts.validate
	local T = HS.contracts and HS.contracts.commandTypes
	local envelopes = (HS.net and HS.net.server and HS.net.server.drain and HS.net.server.drain()) or {}
	local abilityDefs = buildAbilityDefs()
	local names = playerNamesMap(state)
	local hostOnly = {
		[(T and T.START_MATCH) or "start_match"] = true,
		[(T and T.UPDATE_LOADOUT) or "update_loadout"] = true,
	}

	for i = 1, #envelopes do
		local raw = envelopes[i]
		local env, err = validate and validate.commandEnvelope and validate.commandEnvelope(raw)
		if not env then
			logWarn("Dropped invalid command", { reason = tostring(err) })
		else
			if not HS.app.commandDedupe.seen(env.playerId, env.nonce) then
				HS.app.commandDedupe.mark(env.playerId, env.nonce)
				if hostOnly[env.type] and not HS.infra.players.isHost(env.playerId) then
					allEvents[#allEvents + 1] = HS.domain.events.clientToast({ key = "hs.toast.hostOnly" }, 1.4, nil, env.playerId)
				else
					env = normalizeIncomingEnvelope(env, state)
					local nextState, events = HS.domain.reducers.command.reduce(state, env, {
						now = frameNow,
						abilityDefs = abilityDefs,
						playerNames = names,
					})
					state = nextState
					appendAll(allEvents, events)
				end
			end
		end
	end

	return state, allEvents
end

function R.init()
	if HS.net and HS.net.server and HS.net.server.init then
		HS.net.server.init()
	end
	if HS.app and HS.app.commandDedupe and HS.app.commandDedupe.reset then
		HS.app.commandDedupe.reset()
	end
	if HS.infra and HS.infra.events and HS.infra.events.reset then
		HS.infra.events.reset()
	end
	if HS.infra and HS.infra.combat and HS.infra.combat.reset then
		HS.infra.combat.reset()
	end
	if HS.infra and HS.infra.mimic and HS.infra.mimic.reset then
		HS.infra.mimic.reset()
	end
	if HS.infra and HS.infra.effects and HS.infra.effects.reset then
		HS.infra.effects.reset()
	end
	if HS.infra and HS.infra.loadout and HS.infra.loadout.reset then
		HS.infra.loadout.reset(server.hs)
	end
	if HS.infra and HS.infra.snapshot and HS.infra.snapshot.reset then
		HS.infra.snapshot.reset()
	end

	local defaults = (HS.settings and HS.settings.defaults and HS.settings.defaults()) or {}
	local spawns = (HS.infra and HS.infra.world and HS.infra.world.collectSpawns and HS.infra.world.collectSpawns()) or {
		seekers = {},
		hiders = {},
		spectators = {},
		ffa = {},
	}

	local st = HS.domain.model.newState({ settings = defaults, spawns = spawns })
	local frameNow = now()
	local rosterEvents
	st, rosterEvents = syncRoster(st, frameNow)
	logInfo("Runtime initialized", mergeFields(roundFields(st), { now = frameNow }))
	HS.app.store.initServer(st)

	handleEvents(st, nil, rosterEvents, frameNow)
	if HS.infra and HS.infra.effects and HS.infra.effects.syncState then
		HS.infra.effects.syncState(st, nil, frameNow)
	end
	if HS.infra and HS.infra.snapshot and HS.infra.snapshot.write then
		HS.infra.snapshot.write(st, frameNow)
	end

	server.hs = st
end

function R.tick(dt)
	local _dt = tonumber(dt) or 0
	local st = HS.app.store.getServer()
	if type(st) ~= "table" then return end

	local frameNow = now()
	local prevState = HS.domain.model.clone(st)
	local events = {}

	local rosterEvents
	st, rosterEvents = syncRoster(st, frameNow)
	appendAll(events, rosterEvents)

	local commandEvents
	st, commandEvents = processCommands(st, frameNow)
	appendAll(events, commandEvents)

	local tickInput = {
		now = frameNow,
		dt = _dt,
		deaths = (HS.infra and HS.infra.combat and HS.infra.combat.pollDeaths and HS.infra.combat.pollDeaths(st)) or {},
		hurts = (HS.infra and HS.infra.combat and HS.infra.combat.pollHurts and HS.infra.combat.pollHurts()) or {},
		playerNames = playerNamesMap(st),
	}
	local nextState, tickEvents = HS.domain.reducers.tick.reduce(st, tickInput, {
		now = frameNow,
		abilityDefs = buildAbilityDefs(),
	})
	st = nextState
	appendAll(events, tickEvents)

	local nextPhase = tostring(st and st.phase or "")
	local prevPhase = tostring(prevState and prevState.phase or "")
	local nextSetupState = tostring(st and st.setupState or "")
	local prevSetupState = tostring(prevState and prevState.setupState or "")
	local fieldsCache = nil
	local function fields()
		if fieldsCache == nil then
			fieldsCache = roundFields(st)
		end
		return fieldsCache
	end

	if prevSetupState ~= nextSetupState then
		logInfo("Setup state changed", mergeFields(fields(), {
			now = frameNow,
			from = prevSetupState,
			to = nextSetupState,
		}))
	end

	if prevPhase ~= nextPhase then
		logInfo("Phase changed", mergeFields(fields(), {
			now = frameNow,
			from = prevPhase,
			to = nextPhase,
		}))
	end

	if nextPhase ~= prevPhase and nextPhase == HS.const.PHASE_HIDING then
		if HS.infra and HS.infra.combat and HS.infra.combat.suppress then
			HS.infra.combat.suppress(0.75, frameNow)
			logInfo("Death events suppressed after round start", mergeFields(fields(), {
				now = frameNow,
				suppressSeconds = 0.75,
			}))
		end
	end

	if hasToast(events, "hs.toast.needPlayersPerTeam") then
		logWarn("Round start blocked", mergeFields(fields(), {
			now = frameNow,
			prevPhase = prevPhase,
			nextPhase = nextPhase,
		}))
	end
	if hasToast(events, "hs.toast.matchComplete") then
		logInfo("Match reset after round cap", mergeFields(fields(), { now = frameNow }))
	end

	local roundStartedType = (HS.domain and HS.domain.events and HS.domain.events.SRV_ROUND_STARTED) or "srv.round_started"
	if findEvent(events, roundStartedType) then
		logInfo("Round started", mergeFields(fields(), { now = frameNow }))
	end

	local victoryType = (HS.contracts and HS.contracts.eventTypes and HS.contracts.eventTypes.VICTORY) or "ui.victory"
	local victoryEvent = findEvent(events, victoryType)
	if victoryEvent then
		local winner = tostring(victoryEvent.payload and victoryEvent.payload.winner or "")
		logInfo("Round winner decided", mergeFields(fields(), {
			now = frameNow,
			winner = winner,
		}))
	end

	handleEvents(st, prevState, events, frameNow)
	if HS.infra and HS.infra.effects and HS.infra.effects.syncState then
		HS.infra.effects.syncState(st, prevState, frameNow)
	end
	if HS.infra and HS.infra.loadout and HS.infra.loadout.tick then
		HS.infra.loadout.tick(st)
	end

	HS.app.store.setServer(st)
	server.hs = st

	if HS.infra and HS.infra.snapshot and HS.infra.snapshot.write then
		HS.infra.snapshot.write(st, frameNow)
	end
end
