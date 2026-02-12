HS = HS or {}
HS.systems = HS.systems or {}
HS.systems.client = HS.systems.client or {}

HS.systems.client.sceneDraw = HS.systems.client.sceneDraw or {
	name = "scene-draw",
}

function HS.systems.client.sceneDraw.draw(_self, ctx, dt)
	local vm = HS.systems.client.common.anyVm(ctx)
	if vm and vm.phase == HS.const.PHASE_SETUP then
		if HS.ui and HS.ui.scenes and HS.ui.scenes.setup and HS.ui.scenes.setup.draw then
			HS.ui.scenes.setup.draw(dt, ctx, vm)
		end
	elseif vm and vm.ready then
		if HS.ui and HS.ui.scenes and HS.ui.scenes.match and HS.ui.scenes.match.draw then
			HS.ui.scenes.match.draw(dt, ctx, vm)
		end
	end
	return false
end
