HS = HS or {}
HS.domain = HS.domain or {}
HS.domain.reducers = HS.domain.reducers or {}
HS.domain.reducers.tick = HS.domain.reducers.tick or {}

local T = HS.domain.reducers.tick
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

local function resolveName(names, pid)
	if type(names) ~= "table" then return "" end
	return tostring(names[tonumber(pid) or 0] or "")
end

local function mimicId()
	return ((HS.abilities and HS.abilities.ids and HS.abilities.ids.mimicProp) or "mimic_prop")
end

local function mimicCooldownSeconds(ctx)
	local defs = type(ctx and ctx.abilityDefs) == "table" and ctx.abilityDefs or nil
	local def = defs and defs[mimicId()] or nil
	if type(def) ~= "table" and HS.abilities and HS.abilities.def then
		def = HS.abilities.def(mimicId())
	end
	return math.max(0, tonumber(def and def.cooldownSeconds) or 0)
end

local function breakMimic(st, playerId, now, cooldownSeconds)
	playerId = tonumber(playerId) or 0
	if playerId <= 0 then
		return false
	end
	local p = st.players and st.players[playerId] or nil
	if not p or type(p.abilities) ~= "table" then
		return false
	end
	local ab = p.abilities[mimicId()]
	if type(ab) ~= "table" then
		return false
	end
	local untilAt = tonumber(ab.armedUntil) or 0
	if untilAt <= 0 then
		return false
	end
	ab.armedUntil = 0
	if tonumber(cooldownSeconds) and cooldownSeconds > 0 then
		ab.readyAt = math.max(tonumber(ab.readyAt) or 0, now + cooldownSeconds)
	end
	return true
end

local function handleHurts(st, tickInput, ctx)
	local events = {}
	local hurts = type(tickInput) == "table" and tickInput.hurts or nil
	local now = tonumber(tickInput and tickInput.now) or 0
	local cd = mimicCooldownSeconds(ctx)
	if type(hurts) ~= "table" or #hurts == 0 then
		return events
	end
	if st.phase ~= HS.const.PHASE_HIDING and st.phase ~= HS.const.PHASE_SEEKING then
		return events
	end

	for i = 1, #hurts do
		local h = hurts[i]
		local victimId = tonumber(h and h.victimId) or 0
		local attackerId = tonumber(h and h.attackerId) or 0
		if victimId > 0 then
			breakMimic(st, victimId, now, cd)
		end
		if attackerId > 0 then
			breakMimic(st, attackerId, now, cd)
		end
	end
	return events
end

local function handleDeaths(st, tickInput, ctx)
	local events = {}
	local deaths = type(tickInput) == "table" and tickInput.deaths or nil
	local now = tonumber(tickInput and tickInput.now) or 0
	local cd = mimicCooldownSeconds(ctx)
	if type(deaths) ~= "table" or #deaths == 0 then
		return events
	end
	if st.phase ~= HS.const.PHASE_HIDING and st.phase ~= HS.const.PHASE_SEEKING then
		return events
	end

	local names = tickInput and tickInput.playerNames or nil

	for i = 1, #deaths do
		local d = deaths[i]
		local victimId = tonumber(d and d.victimId) or 0
		local attackerId = tonumber(d and d.attackerId) or 0
		if victimId > 0 then
			breakMimic(st, victimId, now, cd)
			if attackerId > 0 then
				breakMimic(st, attackerId, now, cd)
			end
			local victim = st.players[victimId]
			local attacker = st.players[attackerId]
			if victim and victim.out ~= true then
				local method = "kill"
				if attackerId > 0 and attackerId == victimId then
					method = "self"
				end

				if victim.team == HS.const.TEAM_HIDERS then
					if st.settings and st.settings.taggingEnabled ~= true and st.settings.infectionMode == true then
						victim.team = HS.const.TEAM_SEEKERS
						victim.out = false
						events[#events + 1] = {
							type = E.SRV_PLAYER_TO_TEAM,
							payload = {
								playerId = victimId,
								teamId = HS.const.TEAM_SEEKERS,
								revive = true,
							},
						}
					else
						victim.out = true
						events[#events + 1] = {
							type = E.SRV_PLAYER_TO_SPECTATOR,
							payload = { playerId = victimId },
						}
					end
					local attackerName = resolveName(names, attackerId)
					if attackerName == "" and method ~= "self" then
						attackerName = "Unknown"
					end
					events[#events + 1] = E.clientFeed(
						attackerId,
						victimId,
						method,
						tostring(d and d.cause or ""),
						attackerName,
						resolveName(names, victimId),
						0
					)
					elseif victim.team == HS.const.TEAM_SEEKERS then
						local attackerIsHider = attacker and attacker.team == HS.const.TEAM_HIDERS and attacker.out ~= true
						local graceEndsAt = tonumber(st.seekerGraceEndsAt) or 0
						local graceExpired = graceEndsAt <= 0 or now >= graceEndsAt
						local canKill = st.settings and st.settings.allowHidersKillSeekers == true and st.settings.tagOnlyMode ~= true and graceExpired
						if attackerIsHider and canKill then
							victim.out = true
							events[#events + 1] = {
							type = E.SRV_PLAYER_TO_SPECTATOR,
							payload = { playerId = victimId },
						}
					else
						events[#events + 1] = {
							type = E.SRV_RESTORE_HEALTH,
							payload = { playerId = victimId, health = 1.0 },
						}
					end
				end
			end
		end
	end
	return events
end

local function pruneMimicState(st, now, ctx)
	local cd = mimicCooldownSeconds(ctx)
	if st.phase ~= HS.const.PHASE_HIDING and st.phase ~= HS.const.PHASE_SEEKING then
		for _, pid in ipairs(M.sortedPlayerIds(st)) do
			local p = st.players[pid]
			if p and p.abilities and p.abilities[mimicId()] then
				breakMimic(st, pid, now, cd)
			end
		end
		return
	end

	for _, pid in ipairs(M.sortedPlayerIds(st)) do
		local p = st.players[pid]
		local ab = p and p.abilities and p.abilities[mimicId()] or nil
		if type(ab) == "table" then
			local untilAt = tonumber(ab.armedUntil) or 0
			if untilAt > 0 then
				local validRole = p.team == HS.const.TEAM_HIDERS and p.out ~= true
				if not validRole or now >= untilAt then
					breakMimic(st, pid, now, cd)
				end
			end
		end
	end
end

function T.reduce(state, tickInput, ctx)
	local st = M.clone(state or {})
	local events = {}
	local now = tonumber((ctx and ctx.now) or (tickInput and tickInput.now) or 0) or 0

	appendAll(events, handleHurts(st, tickInput, ctx))
	appendAll(events, handleDeaths(st, tickInput, ctx))
	pruneMimicState(st, now, ctx)

	if st.phase == HS.const.PHASE_SETUP then
		local setupState = tostring(st.setupState or "waiting")
		local setupEndsAt = tonumber(st.setupEndsAt) or 0

		if setupState == "countdown" and setupEndsAt > 0 and now >= setupEndsAt then
			st.setupState = "locked"
			st.setupEndsAt = now + 2.5
			return st, events
		end

		if setupState == "locked" and setupEndsAt > 0 and now >= setupEndsAt then
			I.ensureRoundTeams(st)
			if not I.canStartRound(st) then
				st.setupState = "waiting"
				st.setupEndsAt = 0
				events[#events + 1] = E.clientToast({ key = "hs.toast.needPlayersPerTeam" }, 1.8, nil, 0)
				return st, events
			end
			appendAll(events, I.beginRound(st, now))
			return st, events
		end

		return st, events
	end

	local seekers = M.countAlive(st, HS.const.TEAM_SEEKERS)
	local hiders = M.countAlive(st, HS.const.TEAM_HIDERS)

	if st.phase == HS.const.PHASE_HIDING then
		if seekers <= 0 then
			appendAll(events, I.endRound(st, HS.const.WIN_HIDERS, now))
			return st, events
		end
		if hiders <= 0 then
			appendAll(events, I.endRound(st, HS.const.WIN_SEEKERS, now))
			return st, events
		end
		if now >= (tonumber(st.phaseEndsAt) or 0) then
			local grace = tonumber(st.settings and st.settings.seekerGraceSeconds) or 0
			if st.settings and st.settings.allowHidersKillSeekers == true and grace > 0 then
				st.seekerGraceEndsAt = now + grace
			else
				st.seekerGraceEndsAt = 0
			end
			events[#events + 1] = I.setPhase(st, HS.const.PHASE_SEEKING, now)
			events[#events + 1] = E.clientToast({ key = "hs.toast.seekStarted" }, 1.3, nil, 0)
		end
		return st, events
	end

	if st.phase == HS.const.PHASE_SEEKING then
		if seekers <= 0 then
			appendAll(events, I.endRound(st, HS.const.WIN_HIDERS, now))
			return st, events
		end
		if hiders <= 0 then
			appendAll(events, I.endRound(st, HS.const.WIN_SEEKERS, now))
			return st, events
		end
		if now >= (tonumber(st.phaseEndsAt) or 0) then
			appendAll(events, I.endRound(st, HS.const.WIN_HIDERS, now))
			return st, events
		end
		return st, events
	end

	if st.phase == HS.const.PHASE_INTERMISSION then
		if now >= (tonumber(st.phaseEndsAt) or 0) then
			local roundsToPlay = tonumber(st.settings and st.settings.roundsToPlay) or 0
			if roundsToPlay > 0 and (tonumber(st.round) or 0) >= roundsToPlay then
				I.resetToSetup(st)
				events[#events + 1] = E.clientToast({ key = "hs.toast.matchComplete" }, 2.2, nil, 0)
				return st, events
			end
			if st.settings and st.settings.swapTeamsEachRound == true then
				I.swapTeams(st)
			end
			I.ensureRoundTeams(st)
			if not I.canStartRound(st) then
				I.resetToSetup(st)
				events[#events + 1] = E.clientToast({ key = "hs.toast.needPlayersPerTeam" }, 1.8, nil, 0)
				return st, events
			end
			appendAll(events, I.beginRound(st, now))
		end
	end

	return st, events
end
