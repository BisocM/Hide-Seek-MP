HS = HS or {}
HS.systems = HS.systems or {}
HS.systems.client = HS.systems.client or {}

HS.systems.client.abilitiesDraw = HS.systems.client.abilitiesDraw or {
	name = "abilities-draw",
}

function HS.systems.client.abilitiesDraw.draw(_self, ctx, _dt)
	if not (HS.cli and HS.cli.abilities and HS.cli.abilities.draw) then return false end
	local vm = HS.systems.client.common.anyVm(ctx)
	HS.cli.abilities.draw(ctx, vm)
	return false
end
