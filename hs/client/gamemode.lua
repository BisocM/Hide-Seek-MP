HS = HS or {}
HS.cli = HS.cli or {}
HS.cli.app = HS.cli.app or HS.cli.gm or {}
HS.cli.gm = HS.cli.app -- legacy alias

local function enforceSeekerMapSetting(vm)
	if not vm or not vm.ready then return end
	if not vm.settings or vm.settings.seekerMapEnabled == true then return end
	if not vm.me or vm.me.team ~= HS.const.TEAM_SEEKERS then return end

	SetBool("game.disablemap", true)
	if GetBool("game.map.enabled") then
		SetBool("game.map.enabled", false)
	end
end

function HS.cli.app.init()
	if HS.settings and HS.settings.ensureSavegameDefaults then
		HS.settings.ensureSavegameDefaults(HS.persist)
	end
	if HS.cli.admin_menu and HS.cli.admin_menu.init then
		HS.cli.admin_menu.init()
	end
	if HS.cli.spectate and HS.cli.spectate.init then
		HS.cli.spectate.init()
	end
	if HS.cli.abilities and HS.cli.abilities.init then
		HS.cli.abilities.init()
	end
	if HS.cli.timeSync and HS.cli.timeSync.init then
		HS.cli.timeSync.init()
	end
	if HS.cli.toast and HS.cli.toast.init then
		HS.cli.toast.init()
	end
	if HS.cli.feed and HS.cli.feed.init then
		HS.cli.feed.init()
	end
	if HS.cli.trail and HS.cli.trail.init then
		HS.cli.trail.init()
	end
end

function HS.cli.app.tick(dt)
	hudTick(dt)

	if HS.cli.toast and HS.cli.toast.tick then
		HS.cli.toast.tick(dt)
	end
	if HS.cli.feed and HS.cli.feed.tick then
		HS.cli.feed.tick(dt)
	end

	local ctx = HS.ctx and HS.ctx.get and HS.ctx.get() or nil
	local sh = HS.select and HS.select.shared and HS.select.shared() or nil
	local vm = (sh and HS.select and HS.select.matchVm and HS.select.matchVm(ctx, sh)) or nil

	-- Host/admin overlay and tool restrictions need to restore/close cleanly even if `shared.hs` disappears.
	if HS.cli.admin_menu and HS.cli.admin_menu.tick then
		HS.cli.admin_menu.tick(dt, ctx, vm)
	end

	if not sh then return end

	if HS.cli.timeSync and HS.cli.timeSync.tick then
		HS.cli.timeSync.tick(dt, ctx, sh)
	end

	if HS.cli.trail and HS.cli.trail.tick then
		HS.cli.trail.tick(dt)
	end

	enforceSeekerMapSetting(vm)
	if HS.cli.abilities and HS.cli.abilities.tick then
		HS.cli.abilities.tick(dt, ctx, vm)
	end
	if not vm or not vm.ready then return end

	if HS.cli.spectate and HS.cli.spectate.tick then
		HS.cli.spectate.tick(dt, ctx, vm)
	end

	if vm.phase ~= HS.const.PHASE_SEEKING then return end
	if not vm.settings or vm.settings.taggingEnabled ~= true then return end
	if not vm.me or vm.me.team ~= HS.const.TEAM_SEEKERS or vm.me.out then return end

	if HS.input and HS.input.pressed and HS.input.pressed("tag") then
		HS.engine.serverCall("server.hs_requestTag", vm.me.id)
	end
end

function HS.cli.app.draw()
	local ctx = HS.ctx and HS.ctx.get and HS.ctx.get() or nil
	local sh = HS.select and HS.select.shared and HS.select.shared() or nil
	local vm = (HS.select and HS.select.matchVm and HS.select.matchVm(ctx, sh)) or nil
	local dt = HS.engine.timeStep()

	enforceSeekerMapSetting(vm)

	if HS.cli.spectate and HS.cli.spectate.applyCamera then
		HS.cli.spectate.applyCamera(ctx, vm)
	end

	if vm and vm.phase == HS.const.PHASE_SETUP then
		HS.cli.pregame.draw(dt, ctx, vm)
	elseif vm and vm.ready then
		HS.cli.drawInGame(dt, ctx, vm)
	end
	if HS.cli.abilities and HS.cli.abilities.draw then
		HS.cli.abilities.draw(ctx, vm)
	end

	if HS.cli.feed and HS.cli.feed.draw then
		HS.cli.feed.draw()
	end
	if HS.cli.toast and HS.cli.toast.draw then
		HS.cli.toast.draw()
	end
	hudDrawBanner(dt)

	-- Render last so it can sit above other HUD elements.
	if HS.cli.admin_menu and HS.cli.admin_menu.draw then
		HS.cli.admin_menu.draw(dt, ctx, vm)
	end
end
