HS = HS or {}
HS.domain = HS.domain or {}
HS.domain.events = HS.domain.events or {}

local E = HS.domain.events

E.SRV_ROUND_STARTED = "srv.round_started"
E.SRV_PLAYER_TO_SPECTATOR = "srv.player_to_spectator"
E.SRV_PLAYER_TO_TEAM = "srv.player_to_team"
E.SRV_RESTORE_HEALTH = "srv.restore_health"
E.SRV_ABILITY_EXECUTE = "srv.ability_execute"
E.SRV_PHASE_CHANGED = "srv.phase_changed"

function E.clientToast(message, seconds, params, target)
	local types = HS.contracts and HS.contracts.eventTypes
	return {
		type = types and types.TOAST or "ui.toast",
		target = tonumber(target) or 0,
		payload = {
			message = message,
			seconds = tonumber(seconds) or 1.2,
			params = params,
		},
	}
end

function E.clientVictory(winner, target)
	local types = HS.contracts and HS.contracts.eventTypes
	return {
		type = types and types.VICTORY or "ui.victory",
		target = tonumber(target) or 0,
		payload = { winner = tostring(winner or "") },
	}
end

function E.clientFeed(attackerId, victimId, method, cause, attackerName, victimName, target)
	local types = HS.contracts and HS.contracts.eventTypes
	method = tostring(method or "kill")
	local v = tonumber(victimId) or 0
	local a = tonumber(attackerId) or 0
	if a <= 0 and method == "self" then
		a = v
	end
	return {
		type = types and types.FEED_CAUGHT or "ui.feed_caught",
		target = tonumber(target) or 0,
		payload = {
			attackerId = a,
			victimId = v,
			method = method,
			cause = tostring(cause or ""),
			attackerName = tostring(attackerName or ""),
			victimName = tostring(victimName or ""),
		},
	}
end

function E.clientTimeSync(playerId, seq, serverNow, clientSentAt)
	local types = HS.contracts and HS.contracts.eventTypes
	return {
		type = types and types.TIME_SYNC or "time.sync",
		target = tonumber(playerId) or 0,
		payload = {
			seq = tonumber(seq) or 0,
			serverNow = tonumber(serverNow) or 0,
			clientSentAt = tonumber(clientSentAt) or 0,
		},
	}
end

function E.clientAbilityVfx(abilityId, sourcePlayerId, pos, dir, pos2, target)
	local types = HS.contracts and HS.contracts.eventTypes
	pos = type(pos) == "table" and pos or Vec(0, 0, 0)
	dir = type(dir) == "table" and dir or Vec(0, 0, 0)
	pos2 = type(pos2) == "table" and pos2 or pos
	return {
		type = types and types.ABILITY_VFX or "vfx.ability",
		target = tonumber(target) or 0,
		payload = {
			abilityId = tostring(abilityId or ""),
			sourcePlayerId = tonumber(sourcePlayerId) or 0,
			x = tonumber(pos[1]) or 0,
			y = tonumber(pos[2]) or 0,
			z = tonumber(pos[3]) or 0,
			dx = tonumber(dir[1]) or 0,
			dy = tonumber(dir[2]) or 0,
			dz = tonumber(dir[3]) or 0,
			x2 = tonumber(pos2[1]) or 0,
			y2 = tonumber(pos2[2]) or 0,
			z2 = tonumber(pos2[3]) or 0,
		},
	}
end
