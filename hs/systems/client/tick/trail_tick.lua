HS = HS or {}
HS.systems = HS.systems or {}
HS.systems.client = HS.systems.client or {}

HS.systems.client.trailTick = HS.systems.client.trailTick or {
	name = "trail-tick",
}

function HS.systems.client.trailTick.tick(_self, _ctx, _dt)
	if not (HS.cli and HS.cli.trail and HS.cli.trail.tick) then return false end
	if not (HS.select and HS.select.shared and HS.select.shared()) then return false end
	HS.cli.trail.tick(_dt)
	return false
end
