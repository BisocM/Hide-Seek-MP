HS = HS or {}
HS.domain = HS.domain or {}
HS.domain.reducers = HS.domain.reducers or {}
HS.domain.reducers.internal = HS.domain.reducers.internal or {}

local I = HS.domain.reducers.internal
local M = HS.domain.model
local E = HS.domain.events

local function clamp(v, a, b)
	if HS.util and HS.util.math and HS.util.math.clamp then
		return HS.util.math.clamp(v, a, b)
	end
	local n = tonumber(v) or 0
	if n < a then return a end
	if n > b then return b end
	return n
end

function I.phaseDuration(settings, phase)
	settings = type(settings) == "table" and settings or {}
	if phase == HS.const.PHASE_HIDING then
		return clamp(settings.hideSeconds, 20, 180)
	elseif phase == HS.const.PHASE_SEEKING then
		return clamp(settings.seekSeconds, 300, 1800)
	elseif phase == HS.const.PHASE_INTERMISSION then
		return clamp(settings.intermissionSeconds, 10, 60)
	end
	return 0
end

function I.setPhase(st, phase, now)
	st.phase = tostring(phase or HS.const.PHASE_SETUP)
	local d = I.phaseDuration(st.settings, st.phase)
	st.phaseEndsAt = d > 0 and ((tonumber(now) or 0) + d) or 0
	return {
		type = E.SRV_PHASE_CHANGED,
		payload = {
			phase = st.phase,
			phaseEndsAt = st.phaseEndsAt,
		},
	}
end

local function assignedTeamCounts(st)
	local seekers = 0
	local hiders = 0
	for _, pid in ipairs(M.sortedPlayerIds(st)) do
		local p = st.players[pid]
		local t = tonumber(p and p.team) or 0
		if t == HS.const.TEAM_SEEKERS then
			seekers = seekers + 1
		elseif t == HS.const.TEAM_HIDERS then
			hiders = hiders + 1
		end
	end
	return seekers, hiders
end

function I.canStartRound(st)
	if type(st) ~= "table" then
		return false
	end
	if #M.sortedPlayerIds(st) < 2 then
		return false
	end
	local seekers, hiders = assignedTeamCounts(st)
	return seekers > 0 and hiders > 0
end

function I.roundFormationStats(st)
	st = type(st) == "table" and st or {}
	local stats = {
		players = 0,
		assignedSeekers = 0,
		assignedHiders = 0,
		assignedNone = 0,
		baseSeekers = 0,
		baseHiders = 0,
		baseNone = 0,
		aliveSeekers = M.countAlive(st, HS.const.TEAM_SEEKERS),
		aliveHiders = M.countAlive(st, HS.const.TEAM_HIDERS),
		outSeekers = 0,
		outHiders = 0,
		outUnassigned = 0,
		late = 0,
		ready = 0,
		maxTeamDiff = math.max(0, tonumber(st.settings and st.settings.maxTeamDiff) or 0),
	}
	for _, pid in ipairs(M.sortedPlayerIds(st)) do
		local p = st.players[pid]
		if p then
			stats.players = stats.players + 1
			local t = tonumber(p.team) or 0
			if t == HS.const.TEAM_SEEKERS then
				stats.assignedSeekers = stats.assignedSeekers + 1
				if p.out == true then
					stats.outSeekers = stats.outSeekers + 1
				end
			elseif t == HS.const.TEAM_HIDERS then
				stats.assignedHiders = stats.assignedHiders + 1
				if p.out == true then
					stats.outHiders = stats.outHiders + 1
				end
			else
				stats.assignedNone = stats.assignedNone + 1
				if p.out == true then
					stats.outUnassigned = stats.outUnassigned + 1
				end
			end

			local bt = tonumber(p.baseTeam) or 0
			if bt == HS.const.TEAM_SEEKERS then
				stats.baseSeekers = stats.baseSeekers + 1
			elseif bt == HS.const.TEAM_HIDERS then
				stats.baseHiders = stats.baseHiders + 1
			else
				stats.baseNone = stats.baseNone + 1
			end

			if p.late == true then
				stats.late = stats.late + 1
			end
			if p.ready == true then
				stats.ready = stats.ready + 1
			end
		end
	end
	return stats
end

local function projectedCounts(st, playerId, nextTeam)
	local seekers = 0
	local hiders = 0
	local assigned = 0
	local ids = M.sortedPlayerIds(st)
	for _, pid in ipairs(ids) do
		local p = st.players[pid]
		if p then
			local t = tonumber(p.team) or 0
			if pid == playerId then
				t = nextTeam
			end
			if t == HS.const.TEAM_SEEKERS then
				seekers = seekers + 1
				assigned = assigned + 1
			elseif t == HS.const.TEAM_HIDERS then
				hiders = hiders + 1
				assigned = assigned + 1
			end
		end
	end
	return seekers, hiders, assigned, #ids
end

function I.teamJoinAllowed(st, playerId, teamId)
	if teamId ~= HS.const.TEAM_SEEKERS and teamId ~= HS.const.TEAM_HIDERS and teamId ~= 0 then
		return false
	end
	if teamId == 0 then return true end

	local rawMaxDiff = tonumber(st.settings and st.settings.maxTeamDiff)
	if rawMaxDiff == nil then
		return true
	end
	local maxDiff = math.max(0, math.floor(rawMaxDiff))

	local seekers, hiders, assigned, totalPlayers = projectedCounts(st, playerId, teamId)
	local currentDiff = math.abs(seekers - hiders)
	if currentDiff <= maxDiff then
		return true
	end

	-- Allow temporary imbalance if remaining unassigned players can still satisfy maxDiff.
	local unassigned = math.max(0, (tonumber(totalPlayers) or 0) - (tonumber(assigned) or 0))
	local required = currentDiff - maxDiff
	return required <= unassigned
end

local function assignToSmallerTeam(st, playerId)
	local p = M.ensurePlayer(st, playerId)
	if not p then return end
	local seekers, hiders = assignedTeamCounts(st)
	local t = (seekers <= hiders) and HS.const.TEAM_SEEKERS or HS.const.TEAM_HIDERS
	if not I.teamJoinAllowed(st, playerId, t) then
		t = (t == HS.const.TEAM_SEEKERS) and HS.const.TEAM_HIDERS or HS.const.TEAM_SEEKERS
	end
	if I.teamJoinAllowed(st, playerId, t) then
		p.team = t
		p.baseTeam = t
		p.ready = false
		p.out = false
		p.late = false
	end
end

function I.ensureRoundTeams(st)
	for _, pid in ipairs(M.sortedPlayerIds(st)) do
		local p = M.ensurePlayer(st, pid)
		if p then
			local bt = tonumber(p.baseTeam) or 0
			if bt == HS.const.TEAM_SEEKERS or bt == HS.const.TEAM_HIDERS then
				p.team = bt
			elseif p.team == HS.const.TEAM_SEEKERS or p.team == HS.const.TEAM_HIDERS then
				p.baseTeam = p.team
			else
				assignToSmallerTeam(st, pid)
			end
			if p.late == true and (p.team == HS.const.TEAM_SEEKERS or p.team == HS.const.TEAM_HIDERS) then
				p.late = false
			end
		end
	end

	local seekers, hiders = assignedTeamCounts(st)
	local ids = M.sortedPlayerIds(st)
	if #ids >= 2 then
		if seekers == 0 then
			for i = #ids, 1, -1 do
				local pid = ids[i]
				local p = st.players[pid]
				if p and p.team == HS.const.TEAM_HIDERS then
					p.team = HS.const.TEAM_SEEKERS
					p.baseTeam = HS.const.TEAM_SEEKERS
					break
				end
			end
		end
		if hiders == 0 then
			for i = #ids, 1, -1 do
				local pid = ids[i]
				local p = st.players[pid]
				if p and p.team == HS.const.TEAM_SEEKERS then
					p.team = HS.const.TEAM_HIDERS
					p.baseTeam = HS.const.TEAM_HIDERS
					break
				end
			end
		end
	end

	local guard = 0
	local maxDiff = math.max(0, tonumber(st.settings and st.settings.maxTeamDiff) or 1)
	while true do
		local s, h = assignedTeamCounts(st)
		local total = s + h
		if total <= 1 then break end
		local eff = math.max(maxDiff, total % 2)
		local diff = math.abs(s - h)
		if diff <= eff then break end

		local larger = (s > h) and HS.const.TEAM_SEEKERS or HS.const.TEAM_HIDERS
		local smaller = (larger == HS.const.TEAM_SEEKERS) and HS.const.TEAM_HIDERS or HS.const.TEAM_SEEKERS
		local moved = false
		local ids = M.sortedPlayerIds(st)
		for i = #ids, 1, -1 do
			local pid = ids[i]
			local p = st.players[pid]
			if p and p.team == larger then
				p.team = smaller
				p.baseTeam = smaller
				moved = true
				break
			end
		end
		if not moved then break end
		guard = guard + 1
		if guard > 128 then break end
	end
end

function I.beginRound(st, now)
	local events = {}
	st.round = (tonumber(st.round) or 0) + 1
	st.matchActive = true
	st.lastWinner = ""
	st.seekerGraceEndsAt = 0
	st.setupState = "done"
	st.setupEndsAt = 0

	I.ensureRoundTeams(st)

	for _, pid in ipairs(M.sortedPlayerIds(st)) do
		local p = M.ensurePlayer(st, pid)
		if p then
			p.out = false
			p.ready = false
			p.abilities = {}
		end
	end

	events[#events + 1] = {
		type = E.SRV_ROUND_STARTED,
		payload = { round = st.round },
	}
	events[#events + 1] = I.setPhase(st, HS.const.PHASE_HIDING, now)
	events[#events + 1] = E.clientToast({ key = "hs.toast.hideStarted" }, 1.3, nil, 0)
	return events
end

function I.endRound(st, winner, now)
	local events = {}
	st.lastWinner = tostring(winner or "")
	if st.lastWinner == HS.const.WIN_SEEKERS then
		st.scoreSeekers = (tonumber(st.scoreSeekers) or 0) + 1
	elseif st.lastWinner == HS.const.WIN_HIDERS then
		st.scoreHiders = (tonumber(st.scoreHiders) or 0) + 1
	end
	events[#events + 1] = I.setPhase(st, HS.const.PHASE_INTERMISSION, now)
	if st.lastWinner == HS.const.WIN_SEEKERS or st.lastWinner == HS.const.WIN_HIDERS then
		events[#events + 1] = E.clientVictory(st.lastWinner, 0)
	else
		events[#events + 1] = E.clientToast({ key = "hs.toast.roundOver" }, 1.2, nil, 0)
	end
	return events
end

function I.resetToSetup(st)
	st.matchActive = false
	st.round = 0
	st.lastWinner = ""
	st.scoreSeekers = 0
	st.scoreHiders = 0
	st.phase = HS.const.PHASE_SETUP
	st.setupState = "waiting"
	st.setupEndsAt = 0
	st.phaseEndsAt = 0
	st.seekerGraceEndsAt = 0

	for _, pid in ipairs(M.sortedPlayerIds(st)) do
		local p = M.ensurePlayer(st, pid)
		if p then
			p.team = 0
			p.baseTeam = 0
			p.ready = false
			p.out = false
			p.late = false
			p.abilities = {}
		end
	end
end

function I.swapTeams(st)
	for _, pid in ipairs(M.sortedPlayerIds(st)) do
		local p = st.players[pid]
		if p and (p.baseTeam == HS.const.TEAM_SEEKERS or p.baseTeam == HS.const.TEAM_HIDERS) then
			p.baseTeam = (p.baseTeam == HS.const.TEAM_SEEKERS) and HS.const.TEAM_HIDERS or HS.const.TEAM_SEEKERS
			p.team = p.baseTeam
			p.ready = false
		end
	end
end
