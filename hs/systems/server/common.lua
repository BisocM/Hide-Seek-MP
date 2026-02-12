HS = HS or {}
HS.systems = HS.systems or {}
HS.systems.server = HS.systems.server or {}
HS.systems.server.common = HS.systems.server.common or {}

local C = HS.systems.server.common

function C.state()
	return server and server.hs or nil
end

function C.runtime()
	return HS.srv and HS.srv.runtime or nil
end
