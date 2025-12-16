
HS = HS or {}
HS.srv = HS.srv or {}
HS.srv.notify = HS.srv.notify or {}

local N = HS.srv.notify

local function toastPayload(keyOrText, params)
	if type(keyOrText) == "table" then
		return keyOrText
	end
	if type(keyOrText) == "string" and string.sub(keyOrText, 1, 3) == "hs." then
		return { key = keyOrText, params = params }
	end
	return tostring(keyOrText or "")
end

function N.toast(targetPlayerId, keyOrText, seconds, params)
	return HS.engine.clientCall(targetPlayerId or 0, "client.hs_toast", toastPayload(keyOrText, params), tonumber(seconds) or 0)
end

function N.victory(targetPlayerId, winnerId)
	return HS.engine.clientCall(targetPlayerId or 0, "client.hs_victory", tostring(winnerId or ""))
end

function N.feedCaught(targetPlayerId, attackerId, victimId, method)
	return HS.engine.clientCall(targetPlayerId or 0, "client.hs_feedCaught", tonumber(attackerId) or 0, tonumber(victimId) or 0, tostring(method or "tag"))
end

function N.abilityVfx(targetPlayerId, abilityId, pos, dir, pos2, sourcePlayerId)
	abilityId = tostring(abilityId or "")
	pos = type(pos) == "table" and pos or Vec(0, 0, 0)
	dir = type(dir) == "table" and dir or Vec(0, 0, 0)
	pos2 = type(pos2) == "table" and pos2 or pos

	return HS.engine.clientCall(
		targetPlayerId or 0,
		"client.hs_abilityVfx",
		abilityId,
		tonumber(pos[1]) or 0, tonumber(pos[2]) or 0, tonumber(pos[3]) or 0,
		tonumber(dir[1]) or 0, tonumber(dir[2]) or 0, tonumber(dir[3]) or 0,
		tonumber(pos2[1]) or 0, tonumber(pos2[2]) or 0, tonumber(pos2[3]) or 0,
		tonumber(sourcePlayerId) or 0
	)
end
