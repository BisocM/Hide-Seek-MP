HS = HS or {}
HS.infra = HS.infra or {}
HS.infra.players = HS.infra.players or {}

local P = HS.infra.players

function P.listSorted()
	local ids = {}
	if HS.engine and HS.engine.playersSorted then
		ids = HS.engine.playersSorted(HS.ctx and HS.ctx.get and HS.ctx.get() or nil) or {}
	else
		if type(GetAllPlayers) == "function" then
			ids = GetAllPlayers() or {}
		elseif type(Players) == "function" then
			for pid in Players() do
				ids[#ids + 1] = pid
			end
		end
		table.sort(ids)
	end
	return ids
end

function P.isValid(playerId)
	playerId = tonumber(playerId) or 0
	if playerId <= 0 then return false end
	if HS.engine and HS.engine.isPlayerValid then
		return HS.engine.isPlayerValid(playerId) == true
	end
	if type(IsPlayerValid) == "function" then
		return IsPlayerValid(playerId) == true
	end
	return false
end

function P.isHost(playerId)
	playerId = tonumber(playerId) or 0
	if playerId <= 0 then return false end
	if type(IsPlayerHost) == "function" then
		return IsPlayerHost(playerId) == true
	end
	return false
end

function P.name(playerId)
	playerId = tonumber(playerId) or 0
	if playerId <= 0 then return "Unknown" end
	if HS.engine and HS.engine.playerName then
		return HS.engine.playerName(playerId)
	end
	if type(GetPlayerName) == "function" then
		local ok, n = pcall(GetPlayerName, playerId)
		if ok then
			n = tostring(n or "")
			if n ~= "" and n ~= "?" and string.upper(n) ~= "UNKNOWN" then
				return n
			end
		end
	end
	return "P" .. tostring(playerId)
end
