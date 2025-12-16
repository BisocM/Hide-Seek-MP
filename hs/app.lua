
#include "core/init.lua"

#include "mplib/hud.lua"
#include "mplib/teams.lua"

#include "shared/init.lua"

#include "server/spawns.lua"
#include "server/teams.lua"
#include "server/abilities.lua"
#include "server/tagging.lua"
#include "server/round.lua"
#include "server/gamemode.lua"
#include "server/notify.lua"
#include "server/rpc.lua"

#include "client/ui_primitives.lua"
#include "client/toast.lua"
#include "client/feed.lua"
#include "client/notify.lua"
#include "client/hud.lua"
#include "client/abilities.lua"
#include "client/time_sync.lua"
#include "client/spectate.lua"
#include "client/pregame.lua"
#include "client/trail.lua"
#include "client/gamemode.lua"

HS = HS or {}
HS.app = HS.app or {}

local function initContext(side)
	local ctx = HS.ctx.init(side)
	ctx.log = HS.log
	ctx.telemetry = HS.telemetry
	ctx.engine = HS.engine
	ctx.persist = HS.persist
	ctx.i18n = HS.i18n
	ctx.settings = HS.settings
	return ctx
end

HS.app.server = HS.app.server or {}
HS.app.client = HS.app.client or {}

function HS.app.server.init()
	local ctx = initContext("server")
	HS.runtime.beginFrame(ctx, 0)
	if HS.srv and HS.srv.app and HS.srv.app.init then
		HS.srv.app.init()
	end
end

function HS.app.server.tick(dt)
	local ctx = initContext("server")
	HS.runtime.beginFrame(ctx, dt)
	if HS.srv and HS.srv.app and HS.srv.app.tick then
		HS.srv.app.tick(dt)
	end
end

function HS.app.client.init()
	local ctx = initContext("client")
	HS.runtime.beginFrame(ctx, 0)
	if HS.cli and HS.cli.app and HS.cli.app.init then
		HS.cli.app.init()
	end
end

function HS.app.client.tick(dt)
	local ctx = initContext("client")
	HS.runtime.beginFrame(ctx, dt)
	if HS.cli and HS.cli.app and HS.cli.app.tick then
		HS.cli.app.tick(dt)
	end
end

function HS.app.client.draw()
	local ctx = initContext("client")
	HS.runtime.beginFrame(ctx, HS.engine.timeStep())
	if HS.cli and HS.cli.app and HS.cli.app.draw then
		HS.cli.app.draw()
	end
end
