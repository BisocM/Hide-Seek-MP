HS = HS or {}
HS.systems = HS.systems or {}
HS.systems.server = HS.systems.server or {}

HS.systems.server.round = HS.systems.server.round or {
	name = "match-round",
}

function HS.systems.server.round.tick(_self, _ctx, dt)
	local st = HS.systems.server.common.state()
	if not st then return false end
	if HS.srv and HS.srv.tickRound then
		HS.srv.tickRound(st, dt)
	end
	return false
end
