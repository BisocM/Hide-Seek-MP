HS = HS or {}
HS.infra = HS.infra or {}
HS.infra.clock = HS.infra.clock or {}

local C = HS.infra.clock

function C.now()
	if HS.engine and HS.engine.now then
		return HS.engine.now()
	end
	if type(GetTime) == "function" then
		local ok, t = pcall(GetTime)
		if ok then return tonumber(t) or 0 end
	end
	return 0
end
