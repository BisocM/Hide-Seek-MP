HS = HS or {}
HS.systems = HS.systems or {}
HS.systems.client = HS.systems.client or {}

HS.systems.client.cameraDraw = HS.systems.client.cameraDraw or {
	name = "camera-draw",
}

function HS.systems.client.cameraDraw.draw(_self, ctx, _dt)
	local vm = HS.systems.client.common.anyVm(ctx)
	HS.systems.client.common.enforceSeekerMapSetting(vm)
	if HS.cli and HS.cli.spectate and HS.cli.spectate.applyCamera then
		HS.cli.spectate.applyCamera(ctx, vm)
	end
	return false
end
