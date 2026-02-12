HS = HS or {}
HS.ui = HS.ui or {}
HS.ui.scenes = HS.ui.scenes or {}
HS.ui.scenes.match = HS.ui.scenes.match or {}

local S = HS.ui.scenes.match

function S.draw(dt, ctx, vm)
	if not vm or vm.phase == HS.const.PHASE_SETUP then return false end
	if HS.cli and HS.cli.drawInGame then
		HS.cli.drawInGame(dt, ctx, vm)
	end
	return true
end
