
HS = HS or {}
HS.srv = HS.srv or {}
HS.srv.rpc = HS.srv.rpc or {}

function HS.srv.rpc.start(playerId, settings)
	local st = server.hs
	if not st then return end
	if st.phase ~= HS.const.PHASE_SETUP then return end
	if type(settings) ~= "table" then
		local fallback = nil
		if HS.settings and HS.settings.readHostStartPayload then
			fallback = HS.settings.readHostStartPayload(HS.persist)
		end
		if type(fallback) == "table" then
			settings = fallback
		else
			settings = nil
		end
	end

	HS.srv.app.applyHostSettings(st, settings)
	HS.srv.syncShared(st)
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
		HS.srv.syncShared(st)
	else
		HS.srv.notify.toast(playerId, "hs.toast.noHiderInRange", 0.75)
	end
end

function HS.srv.rpc.useAbility(playerId, abilityId)
	return HS.srv.rpc.ability(playerId, abilityId, "use")
end

function HS.srv.rpc.triggerSuperjump(playerId)
	return HS.srv.rpc.ability(playerId, HS.abilities and HS.abilities.ids and HS.abilities.ids.superjump, "trigger")
end

function HS.srv.rpc.ability(playerId, abilityId, event)
	local st = server.hs
	if not st then return end
	if not IsPlayerValid(playerId) then return end
	if not HS.srv.abilities or not HS.srv.abilities.executeAbility then return end

	if HS.srv.abilities.executeAbility(st, playerId, abilityId, event) then
		HS.srv.syncShared(st)
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
	st._settingsCopy = nil -- force syncShared() to deep-copy fresh settings
	HS.srv.syncShared(st)
end

function server.hs_start(playerId, settings, ...)
	local extraPayload = select(1, ...)
	-- Tolerate callers that send only settings and clients/runtimes that shift payload by one argument.
	if type(settings) ~= "table" and type(extraPayload) == "table" then
		settings = extraPayload
	end
	if type(playerId) == "table" and settings == nil then
		settings = playerId
		playerId = 0
	end
	HS.srv.rpc.start(playerId, settings, ...)
end

function server.hs_requestTag(playerId)
	HS.srv.rpc.requestTag(playerId)
end

function server.hs_useAbility(playerId, abilityId)
	HS.srv.rpc.useAbility(playerId, abilityId)
end

function server.hs_triggerSuperjump(playerId)
	HS.srv.rpc.triggerSuperjump(playerId)
end

function server.hs_ability(playerId, abilityId, event)
	HS.srv.rpc.ability(playerId, abilityId, event)
end

function server.hs_timeSync(playerId, seq, clientSentAt)
	HS.srv.rpc.timeSync(playerId, seq, clientSentAt)
end

function server.hs_updateLoadout(playerId, loadout)
	HS.srv.rpc.updateLoadout(playerId, loadout)
end
