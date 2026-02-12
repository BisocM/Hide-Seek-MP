HS = HS or {}
HS.srv = HS.srv or {}

function HS.srv.publishShared(state)
	shared.hs = shared.hs or {}
	local sh = shared.hs

	sh.phase = state.phase
	sh.phaseEndsAt = state.phaseEndsAt or 0
	sh.serverNow = HS.util.now()
	sh.round = state.round or 0
	sh.lastWinner = state.lastWinner or ""
	sh.matchActive = state.matchActive and true or false
	sh.scoreSeekers = state.scoreSeekers or 0
	sh.scoreHiders = state.scoreHiders or 0

	state._settingsCopy = state._settingsCopy or HS.util.deepcopy(state.settings or {})
	sh.settings = state._settingsCopy

	local teamOf = sh.teamOf or {}
	local readyOf = sh.readyOf or {}
	local outOf = sh.outOf or {}
	local abilityReadyAt = sh.abilityReadyAt or {}
	local abilityArmedUntil = sh.abilityArmedUntil or {}
	local defs = (HS.abilities and HS.abilities.list and HS.abilities.list()) or {}
	for k in pairs(teamOf) do teamOf[k] = nil end
	for k in pairs(readyOf) do readyOf[k] = nil end
	for k in pairs(outOf) do outOf[k] = nil end

	for id in pairs(abilityReadyAt) do
		if not (HS.abilities and HS.abilities.def and HS.abilities.def(id)) then
			abilityReadyAt[id] = nil
		end
	end
	for id in pairs(abilityArmedUntil) do
		if not (HS.abilities and HS.abilities.def and HS.abilities.def(id)) then
			abilityArmedUntil[id] = nil
		end
	end

	for i = 1, #defs do
		local id = defs[i].id
		abilityReadyAt[id] = abilityReadyAt[id] or {}
		abilityArmedUntil[id] = abilityArmedUntil[id] or {}
		for k in pairs(abilityReadyAt[id]) do abilityReadyAt[id][k] = nil end
		for k in pairs(abilityArmedUntil[id]) do abilityArmedUntil[id][k] = nil end
	end

	for _, pid in ipairs(HS.util.getPlayersSorted()) do
		local p = state.players[pid]
		if p then
			teamOf[pid] = p.team
			readyOf[pid] = p.ready
			outOf[pid] = p.out

			local abAll = p.abilities
			for i = 1, #defs do
				local def = defs[i]
				local id = def.id
				local perReady = abilityReadyAt[id]
				local perArmed = abilityArmedUntil[id]
				local ab = (type(abAll) == "table") and abAll[id] or nil
				perReady[pid] = (type(ab) == "table" and tonumber(ab.readyAt)) or 0
				perArmed[pid] = (type(ab) == "table" and tonumber(ab.armedUntil)) or 0
			end
		end
	end
	sh.teamOf = teamOf
	sh.readyOf = readyOf
	sh.outOf = outOf
	sh.abilityReadyAt = abilityReadyAt
	sh.abilityArmedUntil = abilityArmedUntil

	sh.hidersRemaining = HS.util.hidersRemaining(state.players)
	sh.seekersCount = HS.util.seekersCount(state.players)
end

local function setPhase(state, phase, durationSeconds)
	state.phase = phase
	state.phaseEndsAt = (durationSeconds and durationSeconds > 0) and (HS.util.now() + durationSeconds) or 0
end

function HS.srv.spawnTeams(state)
	local ids = HS.util.getPlayersSorted()
	for _, pid in ipairs(ids) do
		if IsPlayerValid(pid) then
			local p = state.players[pid]
			if p and p.team == HS.const.TEAM_SEEKERS then
				local tr = HS.util.pickRandom(state.spawns.seekers) or GetPlayerTransform(pid)
				RespawnPlayerAtTransform(tr, pid)
				SetPlayerHealth(1.0, pid)
			elseif p and p.team == HS.const.TEAM_HIDERS then
				local tr = HS.util.pickRandom(state.spawns.hiders) or GetPlayerTransform(pid)
				RespawnPlayerAtTransform(tr, pid)
				SetPlayerHealth(1.0, pid)
			else
				HS.srv.moveToSpectator(state, pid)
			end
		end
	end
end

function HS.srv.beginRound(state)
	state.round = (state.round or 0) + 1
	state.matchActive = true
	state.lastWinner = ""
	state.seekerGraceEndsAt = 0
	HS.srv.resetRoundPlayerState(state)
	if HS.srv.restoreBaseTeams then
		HS.srv.restoreBaseTeams(state)
	end
	HS.srv.assignLateJoiners(state)
	if HS.srv.abilities and HS.srv.abilities.resetRound then
		HS.srv.abilities.resetRound(state)
	end

	local ids = HS.util.getPlayersSorted()
	if #ids >= 2 then
		if HS.util.hidersRemaining(state.players) == 0 then
			for i = #ids, 1, -1 do
				local pid = ids[i]
				local p = state.players[pid]
				if p and p.team == HS.const.TEAM_SEEKERS then
					HS.srv.setTeam(state, pid, HS.const.TEAM_HIDERS)
					state.players[pid].out = false
					break
				end
			end
		end

		if HS.util.seekersCount(state.players) == 0 then
			for i = #ids, 1, -1 do
				local pid = ids[i]
				local p = state.players[pid]
				if p and p.team == HS.const.TEAM_HIDERS then
					HS.srv.setTeam(state, pid, HS.const.TEAM_SEEKERS)
					state.players[pid].out = false
					break
				end
			end
		end
	end

	HS.srv.autoBalance(state)

	HS.srv.spawnTeams(state)

	state.seekerLock = {}
	for _, pid in ipairs(HS.util.getPlayersSorted()) do
		local p = state.players[pid]
		if p and p.team == HS.const.TEAM_SEEKERS then
			state.seekerLock[pid] = GetPlayerTransform(pid)
			SetPlayerWalkingSpeed(0.0, pid)
			SetPlayerCrouchSpeedScale(0.01, pid)
			SetPlayerVelocity(Vec(0, 0, 0), pid)
			ReleasePlayerGrab(pid)
		else
			SetPlayerWalkingSpeed(7.0, pid)
			SetPlayerCrouchSpeedScale(3.0, pid)
		end
	end

	setPhase(state, HS.const.PHASE_HIDING, tonumber(state.settings.hideSeconds) or 20)
	HS.srv.notify.toast(0, "hs.toast.hideStarted", 1.3)
	HS.state.snapshot.syncFromSource(state)
end

function HS.srv.endRound(state, winner)
	state.lastWinner = winner or ""

	local w = state.lastWinner
	if w == HS.const.WIN_SEEKERS then
		state.scoreSeekers = (state.scoreSeekers or 0) + 1
	elseif w == HS.const.WIN_HIDERS then
		state.scoreHiders = (state.scoreHiders or 0) + 1
	end

	setPhase(state, HS.const.PHASE_INTERMISSION, tonumber(state.settings.intermissionSeconds) or 10)

	for _, pid in ipairs(HS.util.getPlayersSorted()) do
		if IsPlayerValid(pid) then
			SetPlayerWalkingSpeed(0.0, pid)
			SetPlayerCrouchSpeedScale(0.01, pid)
			ReleasePlayerGrab(pid)
		end
	end

	local winnerText = state.lastWinner or ""
	if winnerText == HS.const.WIN_SEEKERS or winnerText == HS.const.WIN_HIDERS then
		HS.srv.notify.victory(0, winnerText)
	else
		HS.srv.notify.toast(0, "hs.toast.roundOver", 1.2)
	end
	HS.state.snapshot.syncFromSource(state)
end

function HS.srv.stopMatchToSetup(state)
	HS.srv.app.resetToSetup(state)
end

function HS.srv.tickRound(state, dt)
	local t = HS.util.now()

	if state.phase == HS.const.PHASE_SETUP then
		return
	end

	if state.phase == HS.const.PHASE_HIDING then
		if HS.util.seekersCount(state.players) == 0 then
			HS.srv.endRound(state, HS.const.WIN_HIDERS)
			return
		end

		for pid, lockTr in pairs(state.seekerLock or {}) do
			if IsPlayerValid(pid) then
				SetPlayerTransform(lockTr, pid)
				SetPlayerWalkingSpeed(0.0, pid)
				SetPlayerCrouchSpeedScale(0.01, pid)
				SetPlayerVelocity(Vec(0, 0, 0), pid)
				ReleasePlayerGrab(pid)
			end
		end

		if t >= (state.phaseEndsAt or 0) then
			for _, pid in ipairs(HS.util.getPlayersSorted()) do
				local p = state.players[pid]
				if p and p.team == HS.const.TEAM_SEEKERS and IsPlayerValid(pid) then
					SetPlayerWalkingSpeed(7.0, pid)
					SetPlayerCrouchSpeedScale(3.0, pid)
				end
			end
			local grace = tonumber(state.settings and state.settings.seekerGraceSeconds) or 0
			if state.settings and state.settings.allowHidersKillSeekers == true and grace > 0 then
				state.seekerGraceEndsAt = t + grace
			else
				state.seekerGraceEndsAt = 0
			end
			setPhase(state, HS.const.PHASE_SEEKING, tonumber(state.settings.seekSeconds) or 300)
			HS.srv.notify.toast(0, "hs.toast.seekStarted", 1.3)
			HS.state.snapshot.syncFromSource(state)
		end
		return
	end

	if state.phase == HS.const.PHASE_SEEKING then
		if HS.util.seekersCount(state.players) == 0 then
			HS.srv.endRound(state, HS.const.WIN_HIDERS)
			return
		end

		local anyHiders = HS.util.anyHidersAlive(state.players)
		if not anyHiders then
			HS.srv.endRound(state, HS.const.WIN_SEEKERS)
			return
		end

		if t >= (state.phaseEndsAt or 0) then
			HS.srv.endRound(state, HS.const.WIN_HIDERS)
			return
		end

		return
	end

	if state.phase == HS.const.PHASE_INTERMISSION then
		if t >= (state.phaseEndsAt or 0) then
			local roundsToPlay = tonumber(state.settings.roundsToPlay) or 0
			if roundsToPlay > 0 and (state.round or 0) >= roundsToPlay then
				HS.srv.notify.toast(0, "hs.toast.matchComplete", 2.2)
				HS.srv.stopMatchToSetup(state)
				return
			end

			if state.settings.swapTeamsEachRound then
				HS.srv.swapTeams(state)
			end

			HS.srv.beginRound(state)
		end
		return
	end
end
