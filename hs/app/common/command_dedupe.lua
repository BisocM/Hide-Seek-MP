HS = HS or {}
HS.app = HS.app or {}
HS.app.commandDedupe = HS.app.commandDedupe or {}

local D = HS.app.commandDedupe

D._seen = D._seen or {}
D._order = D._order or {}
D.maxEntries = D.maxEntries or 2048

local function keyFor(playerId, nonce)
	return tostring(math.floor(tonumber(playerId) or 0)) .. "|" .. tostring(nonce or "")
end

function D.reset()
	D._seen = {}
	D._order = {}
end

function D.seen(playerId, nonce)
	nonce = tostring(nonce or "")
	if nonce == "" then return false end
	return D._seen[keyFor(playerId, nonce)] == true
end

function D.mark(playerId, nonce)
	nonce = tostring(nonce or "")
	if nonce == "" then return end
	local key = keyFor(playerId, nonce)
	if D._seen[key] == true then return end
	D._seen[key] = true
	D._order[#D._order + 1] = key
	while #D._order > (D.maxEntries or 2048) do
		local old = table.remove(D._order, 1)
		D._seen[old] = nil
	end
end
