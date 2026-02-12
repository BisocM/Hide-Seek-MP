HS = HS or {}
HS.systems = HS.systems or {}
HS.systems.client = HS.systems.client or {}

HS.systems.client.adminTick = HS.systems.client.adminTick or {
	name = "admin-tick",
}

function HS.systems.client.adminTick.tick(_self, ctx, dt)
	if not (HS.cli and HS.cli.admin_menu and HS.cli.admin_menu.tick) then
		return false
	end
	local _sh, vm = HS.systems.client.common.sharedAndVm(ctx)
	HS.cli.admin_menu.tick(dt, ctx, vm)
	return false
end
