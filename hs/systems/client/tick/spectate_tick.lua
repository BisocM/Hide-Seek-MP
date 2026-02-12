HS = HS or {}
HS.systems = HS.systems or {}
HS.systems.client = HS.systems.client or {}

HS.systems.client.spectateTick = HS.systems.client.spectateTick or {
	name = "spectate-tick",
}

function HS.systems.client.spectateTick.tick(_self, ctx, dt)
	if not (HS.cli and HS.cli.spectate and HS.cli.spectate.tick) then return false end
	local sh, vm = HS.systems.client.common.sharedAndVm(ctx)
	if not sh or not vm or not vm.ready then return false end
	HS.cli.spectate.tick(dt, ctx, vm)
	return false
end
