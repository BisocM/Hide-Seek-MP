HS = HS or {}
HS.systems = HS.systems or {}
HS.systems.client = HS.systems.client or {}

HS.systems.client.abilitiesTick = HS.systems.client.abilitiesTick or {
	name = "abilities-tick",
}

function HS.systems.client.abilitiesTick.tick(_self, ctx, dt)
	if not (HS.cli and HS.cli.abilities and HS.cli.abilities.tick) then return false end
	local sh, vm = HS.systems.client.common.sharedAndVm(ctx)
	if not sh then return false end
	HS.systems.client.common.enforceSeekerMapSetting(vm)
	HS.cli.abilities.tick(dt, ctx, vm)
	return false
end
