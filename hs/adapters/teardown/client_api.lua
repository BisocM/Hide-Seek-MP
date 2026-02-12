HS = HS or {}
HS.adapters = HS.adapters or {}
HS.adapters.client = HS.adapters.client or {}

local A = HS.adapters.client

local function isFn(f)
	return type(f) == "function"
end

function A.now()
	if HS.engine and HS.engine.now then
		return HS.engine.now()
	end
	return (isFn(GetTime) and GetTime()) or 0
end

function A.dt()
	if HS.engine and HS.engine.timeStep then
		return HS.engine.timeStep()
	end
	return (isFn(GetTimeStep) and GetTimeStep()) or 0
end

function A.serverCall(fnName, ...)
	if HS.engine and HS.engine.serverCall then
		return HS.engine.serverCall(fnName, ...)
	end
	if not isFn(ServerCall) then return false end
	return pcall(ServerCall, fnName, ...)
end
