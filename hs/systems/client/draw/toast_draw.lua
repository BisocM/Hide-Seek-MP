HS = HS or {}
HS.systems = HS.systems or {}
HS.systems.client = HS.systems.client or {}

HS.systems.client.toastDraw = HS.systems.client.toastDraw or {
	name = "toast-draw",
}

function HS.systems.client.toastDraw.draw(_self, _ctx, _dt)
	if HS.cli and HS.cli.toast and HS.cli.toast.draw then
		HS.cli.toast.draw()
	end
	return false
end
