HS = HS or {}
HS.systems = HS.systems or {}
HS.systems.server = HS.systems.server or {}

HS.systems.server.playersRoster = HS.systems.server.playersRoster or {
	name = "players-roster",
}

function HS.systems.server.playersRoster.tick(_self, _ctx, _dt)
	local st = HS.systems.server.common.state()
	if not st then return false end

	local rt = HS.systems.server.common.runtime()
	if rt and type(rt.syncPlayerRoster) == "function" then
		if rt.syncPlayerRoster(st) then
			HS.state.snapshot.syncFromSource(st)
		end
	end
	return false
end
