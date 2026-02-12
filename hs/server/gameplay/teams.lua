HS = HS or {}
HS.srv = HS.srv or {}

function HS.srv.ensurePlayer(state, playerId)
	if not state then return nil end
	state.players = state.players or {}
	if state.players[playerId] == nil then
		state.players[playerId] = {
			team = 0, -- 0 = unassigned
			baseTeam = 0,
			ready = false,
			out = false, -- eliminated (non-infection)
			late = false, -- joined after match start
			abilities = {},
		}
	end
	local p = state.players[playerId]
	p.baseTeam = p.baseTeam or p.team or 0
	return state.players[playerId]
end

function HS.srv.setReady(state, playerId, ready)
	local p = HS.srv.ensurePlayer(state, playerId)
	p.ready = ready and true or false
end

function HS.srv.setTeam(state, playerId, teamId)
	local p = HS.srv.ensurePlayer(state, playerId)
	p.team = teamId
	p.baseTeam = teamId
	p.ready = false
end

function HS.srv.setCurrentTeam(state, playerId, teamId)
	local p = HS.srv.ensurePlayer(state, playerId)
	p.team = teamId
	p.ready = false
end

function HS.srv.countTeams(state)
	local c1 = HS.util.countTeam(state.players, HS.const.TEAM_SEEKERS)
	local c2 = HS.util.countTeam(state.players, HS.const.TEAM_HIDERS)
	return c1, c2
end

function HS.srv.teamDiffWouldExceed(state, teamToJoin, maxDiff, playerId)
	maxDiff = math.max(0, tonumber(maxDiff) or 0)

	local c1, c2 = HS.srv.countTeams(state)
	local p = state.players[playerId]
	local old = p and p.team or 0

	if old == HS.const.TEAM_SEEKERS then c1 = c1 - 1 end
	if old == HS.const.TEAM_HIDERS  then c2 = c2 - 1 end

	if teamToJoin == HS.const.TEAM_SEEKERS then c1 = c1 + 1 end
	if teamToJoin == HS.const.TEAM_HIDERS  then c2 = c2 + 1 end

	if teamToJoin == HS.const.TEAM_SEEKERS and c1 > c2 + maxDiff then return true end
	if teamToJoin == HS.const.TEAM_HIDERS  and c2 > c1 + maxDiff then return true end
	return false
end

function HS.srv.autoAssignUnassigned(state)
	local maxDiff = state.settings.maxTeamDiff or 1
	local ids = HS.util.getPlayersSorted()

	for _, pid in ipairs(ids) do
		local p = HS.srv.ensurePlayer(state, pid)
		if p.team == 0 then
			local c1, c2 = HS.srv.countTeams(state)
			local desired = (c1 <= c2) and HS.const.TEAM_SEEKERS or HS.const.TEAM_HIDERS
			if HS.srv.teamDiffWouldExceed(state, desired, maxDiff, pid) then
				desired = 3 - desired
			end
			HS.srv.setTeam(state, pid, desired)
		end
	end
end

function HS.srv.assignLateJoiners(state)
	local maxDiff = state.settings.maxTeamDiff or 1
	for _, pid in ipairs(HS.util.getPlayersSorted()) do
		local p = state.players[pid]
		if p and p.late and p.team == 0 then
			local c1, c2 = HS.srv.countTeams(state)
			local desired = (c1 <= c2) and HS.const.TEAM_SEEKERS or HS.const.TEAM_HIDERS

			if HS.srv.teamDiffWouldExceed(state, desired, maxDiff, pid) then
				local other = 3 - desired
				if not HS.srv.teamDiffWouldExceed(state, other, maxDiff, pid) then
					desired = other
				end
			end

			HS.srv.setTeam(state, pid, desired)
			p.out = false
			p.late = false
		end
	end
end

function HS.srv.autoBalance(state)
	local maxDiff = math.max(0, tonumber(state.settings and state.settings.maxTeamDiff) or 1)

	local function pickCandidate(fromTeam)
		local ids = HS.util.getPlayersSorted()
		local best = 0
		for i = #ids, 1, -1 do
			local pid = ids[i]
			local p = state.players[pid]
			if p and p.team == fromTeam then
				if p.ready == false then
					return pid
				end
				if best == 0 then best = pid end
			end
		end
		return best
	end

	local guard = 0
	while true do
		local c1, c2 = HS.srv.countTeams(state)
		local total = c1 + c2
		if total <= 1 then break end
		local effMaxDiff = math.max(maxDiff, total % 2)
		local diff = math.abs(c1 - c2)
		if diff <= effMaxDiff then break end

		local larger = (c1 > c2) and HS.const.TEAM_SEEKERS or HS.const.TEAM_HIDERS
		local smaller = 3 - larger
		local pid = pickCandidate(larger)
		if pid == 0 then break end
		HS.srv.setTeam(state, pid, smaller)

		guard = guard + 1
		if guard > (total + 6) then
			break
		end
	end
end

function HS.srv.swapTeams(state)
	local ids = HS.util.getPlayersSorted()
	for _, pid in ipairs(ids) do
		local p = state.players[pid]
		if p and (p.baseTeam == HS.const.TEAM_SEEKERS or p.baseTeam == HS.const.TEAM_HIDERS) then
			p.baseTeam = 3 - p.baseTeam
			p.team = p.baseTeam
			p.ready = false
		end
	end
end

function HS.srv.restoreBaseTeams(state)
	if not state or not state.players then return end
	for _, pid in ipairs(HS.util.getPlayersSorted()) do
		local p = state.players[pid]
		if p then
			local bt = p.baseTeam or p.team or 0
			p.baseTeam = bt
			p.team = bt
			p.ready = false
		end
	end
end

function HS.srv.resetRoundPlayerState(state)
	for _, pid in ipairs(HS.util.getPlayersSorted()) do
		local p = state.players[pid]
		if p then
			p.out = false
		end
	end
end
