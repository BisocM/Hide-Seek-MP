HS = HS or {}
HS.domain = HS.domain or {}
HS.domain.loadout = HS.domain.loadout or {}

local L = HS.domain.loadout

function L.normalize(loadout, base)
	if HS.loadout and HS.loadout.normalize then
		return HS.loadout.normalize(loadout or {}, base)
	end
	return type(loadout) == "table" and loadout or { enabled = false, tools = {}, assign = {} }
end
