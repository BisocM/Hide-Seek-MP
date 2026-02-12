HS = HS or {}
HS.systems = HS.systems or {}
HS.systems.client = HS.systems.client or {}

HS.systems.client.adminDraw = HS.systems.client.adminDraw or {
	name = "admin-draw",
}

function HS.systems.client.adminDraw.draw(_self, ctx, dt)
	if not (HS.cli and HS.cli.admin_menu and HS.cli.admin_menu.draw) then return false end
	local _sh, vm = HS.systems.client.common.sharedAndVm(ctx)
	HS.cli.admin_menu.draw(dt, ctx, vm)
	return false
end
