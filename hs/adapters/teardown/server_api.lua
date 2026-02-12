HS = HS or {}
HS.adapters = HS.adapters or {}
HS.adapters.server = HS.adapters.server or {}

local A = HS.adapters.server

local function isFn(f)
	return type(f) == "function"
end

function A.now()
	if HS.engine and HS.engine.now then
		return HS.engine.now()
	end
	return (isFn(GetTime) and GetTime()) or 0
end

function A.playersSorted(ctx)
	if HS.engine and HS.engine.playersSorted then
		return HS.engine.playersSorted(ctx)
	end
	local ids = (isFn(GetAllPlayers) and GetAllPlayers()) or {}
	table.sort(ids)
	return ids
end

function A.isPlayerValid(playerId)
	return HS.engine and HS.engine.isPlayerValid and HS.engine.isPlayerValid(playerId)
end

function A.clientCall(targetPlayerId, fnName, ...)
	if HS.engine and HS.engine.clientCall then
		return HS.engine.clientCall(targetPlayerId, fnName, ...)
	end
	if not isFn(ClientCall) then return false end
	return pcall(ClientCall, targetPlayerId, fnName, ...)
end
