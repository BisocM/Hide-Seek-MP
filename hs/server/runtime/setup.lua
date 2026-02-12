HS = HS or {}
HS.srv = HS.srv or {}
HS.srv.runtime = HS.srv.runtime or {}

local R = HS.srv.runtime

function R.setupTeamsForMode(state)
	if shared and shared._hud then
		shared._hud.gameIsSetup = false
	end
	teamsInit(2)
	teamsSetNames({ "hs.team.seekers", "hs.team.hiders" })
	teamsSetColors({ { 0.8, 0.25, 0.2, 1 }, { 0.2, 0.55, 0.8, 1 } })
	teamsSetMaxDiff(state and state.settings and state.settings.maxTeamDiff)
end

function R.onTeamsLocked(state)
	for _, pid in ipairs(HS.util.getPlayersSorted()) do
		local p = HS.srv.ensurePlayer(state, pid)
		p.team = teamsGetTeamId(pid)
		p.baseTeam = p.team
		p.ready = false
		p.out = false
		p.late = false
	end

	local c1, c2 = HS.srv.countTeams(state)
	if c1 == 0 or c2 == 0 then
		HS.srv.app.resetToSetup(state, "hs.toast.needPlayersPerTeam")
		return
	end

	HS.srv.beginRound(state)
end

function R.syncPlayerRoster(state)
	state.players = state.players or {}
	state._presentPlayers = state._presentPlayers or {}
	local present = state._presentPlayers
	for k in pairs(present) do
		present[k] = nil
	end

	local changed = false
	for _, pid in ipairs(HS.util.getPlayersSorted()) do
		present[pid] = true
		if state.players[pid] == nil then
			changed = true
			local p = HS.srv.ensurePlayer(state, pid)
			if state.phase == HS.const.PHASE_SETUP then
				HS.srv.notify.toast(pid, "hs.toast.welcome", 2.4)
			else
				p.team = 0
				p.baseTeam = 0
				p.out = true
				p.late = true
				HS.srv.moveToSpectator(state, pid)
				HS.srv.notify.toast(pid, "hs.toast.lateJoin", 2.6)
			end
		end
	end

	for pid in pairs(state.players) do
		if not present[pid] then
			state.players[pid] = nil
			changed = true
		end
	end

	return changed
end
