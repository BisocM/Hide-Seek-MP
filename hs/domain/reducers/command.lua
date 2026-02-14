HS = HS or {}
HS.domain = HS.domain or {}
HS.domain.reducers = HS.domain.reducers or {}
HS.domain.reducers.command = HS.domain.reducers.command or {}

local C = HS.domain.reducers.command
local M = HS.domain.model
local I = HS.domain.reducers.internal
local E = HS.domain.events

local function appendAll(dst, src)
	if HS.util and HS.util.table and HS.util.table.appendAll then
		HS.util.table.appendAll(dst, src)
		return
	end
	for i = 1, #(src or {}) do
		dst[#dst + 1] = src[i]
	end
end

local function abilityConfig(ctx, abilityId)
	ctx = type(ctx) == "table" and ctx or {}
	local defs = type(ctx.abilityDefs) == "table" and ctx.abilityDefs or {}
	return defs[tostring(abilityId or "")]
end

local function normalizeMethod(attackerId, victimId)
	attackerId = tonumber(attackerId) or 0
	victimId = tonumber(victimId) or 0
	if attackerId <= 0 or attackerId == victimId then
		return "self"
	end
	return "kill"
end

local function resolveName(ctx, pid)
	local names = ctx and ctx.playerNames
	if type(names) ~= "table" then return "" end
	return tostring(names[tonumber(pid) or 0] or "")
end

local function mimicToastKey(reason)
	if HS.contracts and HS.contracts.abilityErrors and HS.contracts.abilityErrors.mimicToastKey then
		return HS.contracts.abilityErrors.mimicToastKey(reason)
	end
	return "hs.toast.mimicUnavailable"
end

local function applyTagOutcome(st, seekerId, hiderId, reason, ctx)
	local events = {}
	local hp = st.players[hiderId]
	if not hp or hp.out == true then
		return events
	end

	if st.settings and st.settings.infectionMode == true then
		hp.team = HS.const.TEAM_SEEKERS
		hp.out = false
		events[#events + 1] = {
			type = E.SRV_PLAYER_TO_TEAM,
			payload = {
				playerId = hiderId,
				teamId = HS.const.TEAM_SEEKERS,
				revive = true,
			},
		}
	else
		hp.out = true
		events[#events + 1] = {
			type = E.SRV_PLAYER_TO_SPECTATOR,
			payload = { playerId = hiderId },
		}
	end

	events[#events + 1] = E.clientFeed(
		seekerId,
		hiderId,
		reason or "tag",
		"",
		resolveName(ctx, seekerId),
		resolveName(ctx, hiderId),
		0
	)
	return events
end

local function handleAbility(st, env, ctx)
	local events = {}
	local payload = type(env.payload) == "table" and env.payload or {}
	local abilityId = tostring(payload.abilityId or "")
	local eventName = tostring(payload.event or "use")
	if abilityId == "" then
		return events
	end

	local p = M.ensurePlayer(st, env.playerId)
	if not p or p.team ~= HS.const.TEAM_HIDERS or p.out == true then
		return events
	end
	if st.phase ~= HS.const.PHASE_HIDING and st.phase ~= HS.const.PHASE_SEEKING then
		return events
	end
	if st.settings and st.settings.hiderAbilitiesEnabled == false then
		return events
	end

	local now = tonumber(ctx and ctx.now) or 0
	local def = abilityConfig(ctx, abilityId)
	if type(def) ~= "table" then
		return events
	end

	local ab = M.ensureAbilityState(p, abilityId)
	if not ab then return events end

	local mimicId = ((HS.abilities and HS.abilities.ids and HS.abilities.ids.mimicProp) or "mimic_prop")
	local superjumpId = ((HS.abilities and HS.abilities.ids and HS.abilities.ids.superjump) or "superjump")
	local mimicDef = abilityConfig(ctx, mimicId)
	local mimicCooldownSeconds = math.max(0, tonumber(mimicDef and mimicDef.cooldownSeconds) or 0)
	local mimicState = p.abilities and p.abilities[mimicId] or nil
	local function breakMimicByAbility()
		if abilityId == mimicId then
			return
		end
		if type(mimicState) ~= "table" then
			return
		end
		local armedUntil = tonumber(mimicState.armedUntil) or 0
		if armedUntil > now then
			mimicState.armedUntil = 0
			if mimicCooldownSeconds > 0 then
				mimicState.readyAt = math.max(tonumber(mimicState.readyAt) or 0, now + mimicCooldownSeconds)
			end
		end
	end

	local cooldownSeconds = tonumber(def.cooldownSeconds) or 0
	if eventName == "use" then
		if now < (tonumber(ab.readyAt) or 0) then
			return events
		end
			if abilityId == superjumpId then
				local armSeconds = tonumber(def.cfg and def.cfg.armSeconds) or 6.0
				if (tonumber(ab.armedUntil) or 0) > now then
					return events
				end
				breakMimicByAbility()
				ab.armedUntil = now + armSeconds
				ab.readyAt = now + cooldownSeconds
			elseif abilityId == mimicId then
				if (tonumber(ab.armedUntil) or 0) > now then
					return events
				end
				local bodyId = math.floor(tonumber(payload.mimicBodyId) or 0)
				if bodyId <= 0 then
					local key = mimicToastKey(payload.mimicReason)
					events[#events + 1] = E.clientToast({ key = key }, 1.6, nil, env.playerId)
					return events
				end
				local durationSeconds = math.max(1.0, tonumber(def.cfg and def.cfg.durationSeconds) or 10.0)
				ab.readyAt = now
				ab.armedUntil = now + durationSeconds
				events[#events + 1] = {
				type = E.SRV_ABILITY_EXECUTE,
				payload = {
					playerId = env.playerId,
					abilityId = abilityId,
					event = eventName,
					mimicBodyId = bodyId,
					mimicReason = tostring(payload.mimicReason or ""),
				},
			}
		else
			breakMimicByAbility()
			ab.readyAt = now + cooldownSeconds
			events[#events + 1] = {
				type = E.SRV_ABILITY_EXECUTE,
				payload = {
					playerId = env.playerId,
					abilityId = abilityId,
					event = eventName,
				},
			}
		end
	elseif eventName == "trigger" then
		if abilityId ~= superjumpId then
			return events
		end
		if now >= (tonumber(ab.armedUntil) or 0) then
			return events
		end
		breakMimicByAbility()
		ab.armedUntil = 0
		events[#events + 1] = {
			type = E.SRV_ABILITY_EXECUTE,
			payload = {
				playerId = env.playerId,
				abilityId = abilityId,
				event = eventName,
			},
		}
	end

	return events
end

function C.reduce(state, envelope, ctx)
	local st = M.clone(state or {})
	local events = {}
	local T = HS.contracts and HS.contracts.commandTypes
	if not T or type(envelope) ~= "table" then
		return st, events
	end

	local ctype = tostring(envelope.type or "")
	local payload = type(envelope.payload) == "table" and envelope.payload or {}
	local playerId = tonumber(envelope.playerId) or 0
	local now = tonumber(ctx and ctx.now) or 0

	if ctype == T.TEAM_JOIN then
		if st.phase ~= HS.const.PHASE_SETUP then
			return st, events
		end
		if tostring(st.setupState or "waiting") == "locked" then
			return st, events
		end
		local teamId = M.clampTeamId(payload.teamId)
		local p = M.ensurePlayer(st, playerId)
		if not p then
			return st, events
		end
		if not I.teamJoinAllowed(st, playerId, teamId) then
			events[#events + 1] = E.clientToast({ key = "hs.toast.teamImbalance" }, 1.4, nil, playerId)
			return st, events
		end
		p.team = teamId
		if teamId == HS.const.TEAM_SEEKERS or teamId == HS.const.TEAM_HIDERS then
			p.baseTeam = teamId
		end
		p.ready = false
		p.out = false
		p.late = false
		return st, events
	end

	if ctype == T.START_MATCH then
		if st.phase ~= HS.const.PHASE_SETUP then
			return st, events
		end
		local setupState = tostring(st.setupState or "waiting")
		if setupState == "countdown" or setupState == "locked" then
			return st, events
		end
		local incoming = type(payload.settings) == "table" and payload.settings or payload
		if type(incoming) == "table" then
			st.settings = M.clone(incoming)
		end

		if #M.sortedPlayerIds(st) < 2 then
			events[#events + 1] = E.clientToast({ key = "hs.toast.needPlayersPerTeam" }, 1.8, nil, playerId)
			return st, events
		end

		st.setupState = "countdown"
		st.setupEndsAt = now + 3.0
		return st, events
	end

	if ctype == T.REQUEST_TAG then
		if st.phase ~= HS.const.PHASE_SEEKING then
			return st, events
		end
		if not (st.settings and st.settings.taggingEnabled == true) then
			events[#events + 1] = E.clientToast({ key = "hs.toast.taggingOffEliminate" }, 1.4, nil, playerId)
			return st, events
		end
		local seeker = M.ensurePlayer(st, playerId)
		if not seeker or seeker.team ~= HS.const.TEAM_SEEKERS or seeker.out == true then
			return st, events
		end
		local targetId = tonumber(payload.targetId) or 0
		local hp = st.players[targetId]
		if not hp or hp.team ~= HS.const.TEAM_HIDERS or hp.out == true then
			events[#events + 1] = E.clientToast({ key = "hs.toast.noHiderInRange" }, 0.75, nil, playerId)
			return st, events
		end
		appendAll(events, applyTagOutcome(st, playerId, targetId, "tag", ctx))
		return st, events
	end

	if ctype == T.UPDATE_LOADOUT then
		if type(payload.loadout) == "table" then
			st.settings = st.settings or {}
			st.settings.loadout = M.clone(payload.loadout)
		end
		return st, events
	end

	if ctype == T.TIME_SYNC then
		events[#events + 1] = E.clientTimeSync(playerId, payload.seq, now, payload.clientSentAt)
		return st, events
	end

	if ctype == T.ABILITY then
		appendAll(events, handleAbility(st, envelope, ctx))
		return st, events
	end

	if ctype == "__roster_sync" then
		local added = type(payload.added) == "table" and payload.added or {}
		local removed = type(payload.removed) == "table" and payload.removed or {}
		for i = 1, #added do
			local pid = tonumber(added[i]) or 0
			if pid > 0 then
				local p = M.ensurePlayer(st, pid)
				if p and st.phase ~= HS.const.PHASE_SETUP then
					p.team = 0
					p.baseTeam = 0
					p.out = true
					p.late = true
					events[#events + 1] = {
						type = E.SRV_PLAYER_TO_SPECTATOR,
						payload = { playerId = pid },
					}
					events[#events + 1] = E.clientToast({ key = "hs.toast.lateJoin" }, 2.4, nil, pid)
				elseif p and st.phase == HS.const.PHASE_SETUP then
					events[#events + 1] = E.clientToast({ key = "hs.toast.welcome" }, 2.0, nil, pid)
				end
			end
		end
		for i = 1, #removed do
			local pid = tonumber(removed[i]) or 0
			if pid > 0 then
				st.players[pid] = nil
			end
		end
		return st, events
	end

	return st, events
end
