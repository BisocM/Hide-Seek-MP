HS = HS or {}
HS.systems = HS.systems or {}
HS.systems.server = HS.systems.server or {}

HS.systems.server.loadout = HS.systems.server.loadout or {
	name = "loadout",
}

function HS.systems.server.loadout.tick(_self, _ctx, dt)
	local st = HS.systems.server.common.state()
	if not st then return false end
	if HS.srv and HS.srv.loadout and HS.srv.loadout.tick then
		HS.srv.loadout.tick(st, dt)
	end
	return false
end
