HS = HS or {}
HS.util = HS.util or {}
HS.util.time = HS.util.time or {}

local T = HS.util.time

function T.now()
	if HS.infra and HS.infra.clock and HS.infra.clock.now then
		return tonumber(HS.infra.clock.now()) or 0
	end
	if HS.engine and HS.engine.now then
		return tonumber(HS.engine.now()) or 0
	end
	if type(GetTime) == "function" then
		return tonumber(GetTime()) or 0
	end
	return 0
end

function T.timeStep()
	if HS.engine and HS.engine.timeStep then
		return tonumber(HS.engine.timeStep()) or 0
	end
	if type(GetTimeStep) == "function" then
		return tonumber(GetTimeStep()) or 0
	end
	return 0
end

HS.util.now = T.now
