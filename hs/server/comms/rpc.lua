
HS = HS or {}
HS.srv = HS.srv or {}
HS.srv.rpc = HS.srv.rpc or {}

function HS.srv.rpc.start(playerId, settings)
	local st = server.hs
	if not st then return end
	if not IsPlayerValid(playerId) then return end
	if not IsPlayerHost(playerId) then return end
	if st.phase ~= HS.const.PHASE_SETUP then return end

	HS.srv.app.applyHostSettings(st, settings)
	HS.state.snapshot.syncFromSource(st)

	if shared and shared._hud then
		shared._hud.gameIsSetup = true
	end

	teamsStart(false)
end

function HS.srv.rpc.requestTag(playerId)
	local st = server.hs
	if not st then return end
	if st.phase ~= HS.const.PHASE_SEEKING then return end
	if not IsPlayerValid(playerId) then return end
	if st.settings and st.settings.taggingEnabled ~= true then
		HS.srv.notify.toast(playerId, "hs.toast.taggingOffEliminate", 1.4)
		return
	end

	if HS.srv.tryTag(st, playerId) then
		HS.state.snapshot.syncFromSource(st)
	else
		HS.srv.notify.toast(playerId, "hs.toast.noHiderInRange", 0.75)
	end
end

function HS.srv.rpc.ability(playerId, abilityId, event)
	local st = server.hs
	if not st then return end
	if not IsPlayerValid(playerId) then return end
	if not HS.srv.abilities or not HS.srv.abilities.executeAbility then return end

	if HS.srv.abilities.executeAbility(st, playerId, abilityId, event) then
		HS.state.snapshot.syncFromSource(st)
	end
end

function HS.srv.rpc.timeSync(playerId, seq, clientSentAt)
	if not IsPlayerValid(playerId) then return end
	seq = tonumber(seq) or 0
	local serverNow = HS.util.now()
	HS.engine.clientCall(playerId, "client.hs_timeSync", seq, serverNow, tonumber(clientSentAt) or 0)
end

function HS.srv.rpc.updateLoadout(playerId, loadout)
	local st = server.hs
	if not st then return end
	if not IsPlayerValid(playerId) then return end
	if not IsPlayerHost(playerId) then return end
	if not (HS.loadout and HS.loadout.normalize) then return end

	st.settings = st.settings or HS.defaults.make()
	st.settings.loadout = HS.loadout.normalize(loadout or {}, st.settings.loadout)
	st._settingsCopy = nil -- force publish source to deep-copy fresh settings
	HS.state.snapshot.syncFromSource(st)
end

function HS.srv.rpc.teamJoin(playerId, teamId)
	local st = server.hs
	if not st then return end
	if st.phase ~= HS.const.PHASE_SETUP then return end
	if not IsPlayerValid(playerId) then return end
	if not (HS.srv and HS.srv.queueTeamJoin) then return end

	HS.srv.queueTeamJoin(playerId, teamId)
end
