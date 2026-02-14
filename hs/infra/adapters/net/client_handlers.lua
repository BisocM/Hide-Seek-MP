HS = HS or {}
HS.net = HS.net or {}
HS.net.client = HS.net.client or {}

local N = HS.net.client

N.handlers = N.handlers or {}

function N.init()
	N.handlers = N.handlers or {}
end

function N.register(name, fn)
	name = tostring(name or "")
	if name == "" or type(fn) ~= "function" then
		return false
	end
	N.handlers[name] = fn
	return true
end

function N.dispatch(name, ...)
	local fn = N.handlers and N.handlers[tostring(name or "")]
	if type(fn) ~= "function" then return false end
	return pcall(fn, ...)
end

local function logWarn(msg, data)
	if HS.log and HS.log.warn then
		HS.log.warn(msg, data)
	end
end

local function callClientFn(name, ...)
	local fn = client and client[name]
	if type(fn) ~= "function" then
		return false
	end
	local ok, err = pcall(fn, ...)
	if not ok then
		logWarn("Client event handler failed", { fn = name, err = tostring(err) })
		return false
	end
	return true
end

local function registerDefaultEventHandlers()
	local types = HS.contracts and HS.contracts.eventTypes
	if not types then
		return
	end

	N.register(types.TOAST, function(payload)
		return callClientFn("hs_toast", payload.message, payload.seconds, payload.params)
	end)

	N.register(types.VICTORY, function(payload)
		return callClientFn("hs_victory", payload.winner)
	end)

	N.register(types.FEED_CAUGHT, function(payload)
		return callClientFn(
			"hs_feedCaught",
			payload.attackerId,
			payload.victimId,
			payload.method,
			payload.attackerName,
			payload.victimName,
			payload.cause
		)
	end)

	N.register(types.ABILITY_VFX, function(payload)
		return callClientFn(
			"hs_abilityVfx",
			payload.abilityId,
			payload.x, payload.y, payload.z,
			payload.dx, payload.dy, payload.dz,
			payload.x2, payload.y2, payload.z2,
			payload.sourcePlayerId
		)
	end)

	N.register(types.TIME_SYNC, function(payload)
		return callClientFn("hs_timeSync", payload.seq, payload.serverNow, payload.clientSentAt)
	end)
end

registerDefaultEventHandlers()

function client.hs_event(envelope)
	local validate = HS.contracts and HS.contracts.validate
	local env, err = validate and validate.eventEnvelope and validate.eventEnvelope(envelope)
	if not env then
		logWarn("Dropped invalid server event", { reason = err })
		return
	end
	N.dispatch(env.type, env.payload)
end
