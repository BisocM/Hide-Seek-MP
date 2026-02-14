HS = HS or {}
HS.srv = HS.srv or {}

function HS.srv.syncShared(state)
	local t = HS.infra and HS.infra.clock and HS.infra.clock.now and HS.infra.clock.now() or 0
	if HS.infra and HS.infra.snapshot and HS.infra.snapshot.write then
		return HS.infra.snapshot.write(state, t)
	end
	return false
end

HS.srv.publishShared = HS.srv.syncShared
