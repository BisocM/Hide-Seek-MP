HS = HS or {}
HS.srv = HS.srv or {}
HS.srv.app = HS.srv.app or {}

local function runtime()
	return HS.srv and HS.srv.runtime or nil
end

function HS.srv.app.applyHostSettings(state, settings)
	state.settings = state.settings or HS.defaults.make()
	local prevLoadout = state.settings.loadout
	local normalized = (HS.settings and HS.settings.normalize and HS.settings.normalize(settings, state.settings)) or (settings or state.settings)

	if HS.loadout and HS.loadout.normalize then
		local incoming = settings and settings.loadout
		normalized.loadout = HS.loadout.normalize(incoming, prevLoadout)
	end

	state.settings = normalized
	state._settingsCopy = HS.util.deepcopy(normalized)

	teamsSetMaxDiff(normalized.maxTeamDiff)
end

function HS.srv.app.resetToSetup(state, reason)
	state.matchActive = false
	state.round = 0
	state.lastWinner = ""
	state.scoreSeekers = 0
	state.scoreHiders = 0
	state.phase = HS.const.PHASE_SETUP
	state.phaseEndsAt = 0
	state.seekerLock = {}
	state.seekerGraceEndsAt = 0
	state.insufficientPlayersSince = nil

	local rt = runtime()
	if rt and rt.setupTeamsForMode then
		rt.setupTeamsForMode(state)
	end

	for _, pid in ipairs(HS.util.getPlayersSorted()) do
		local p = state.players[pid]
		if p then
			p.team = 0
			p.baseTeam = 0
			p.ready = false
			p.out = false
			p.late = false
			p.abilities = {}
		end
	end

	HS.state.snapshot.syncFromSource(state)
	if reason and reason ~= "" then
		if HS.srv.notify and HS.srv.notify.toast then
			HS.srv.notify.toast(0, reason, 2.2)
		else
			HS.engine.clientCall(0, "client.hs_toast", tostring(reason), 2.2)
		end
	end
end

function HS.srv.app.init()
	SetRandomSeed(math.floor(HS.util.now() * 1000))
	hudInit(false)

	if not (HS.domain and HS.domain.types and type(HS.domain.types.newMatchState) == "function") then
		error("Missing domain.types.newMatchState")
	end
	local initial = HS.domain.types.newMatchState({
		spawns = HS.srv.collectSpawns(),
	})
	server.hs = initial

	local rt = runtime()
	if rt and rt.setupTeamsForMode then
		rt.setupTeamsForMode(server.hs)
	end

	for _, pid in ipairs(HS.util.getPlayersSorted()) do
		HS.srv.ensurePlayer(server.hs, pid)
	end

	HS.state.snapshot.syncFromSource(server.hs)
end
