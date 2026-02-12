HS = HS or {}
HS.systems = HS.systems or {}
HS.systems.server = HS.systems.server or {}

HS.systems.server.abilities = HS.systems.server.abilities or {
	name = "abilities",
}

function HS.systems.server.abilities.tick(_self, _ctx, dt)
	local st = HS.systems.server.common.state()
	if not st then return false end
	if HS.srv and HS.srv.abilities and HS.srv.abilities.tick then
		if HS.srv.abilities.tick(st, dt) then
			HS.state.snapshot.syncFromSource(st)
		end
	end
	return false
end
