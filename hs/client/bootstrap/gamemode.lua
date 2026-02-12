HS = HS or {}
HS.cli = HS.cli or {}
HS.cli.app = HS.cli.app or {}

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
