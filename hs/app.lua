#include "core/init.lua"

#include "mplib/hud.lua"
#include "mplib/teams.lua"

#include "shared/init.lua"

#include "server/world/spawns.lua"
#include "server/gameplay/teams.lua"
#include "server/gameplay/abilities.lua"
#include "server/gameplay/tagging.lua"
#include "server/gameplay/round.lua"
#include "server/gameplay/loadout.lua"
#include "server/runtime/init.lua"
#include "server/bootstrap/gamemode.lua"
#include "server/comms/notify.lua"
#include "server/comms/rpc.lua"

#include "client/ui/primitives.lua"
#include "client/ui/toast.lua"
#include "client/ui/feed.lua"
#include "client/ui/notify.lua"
#include "client/ui/hud.lua"
#include "client/gameplay/abilities.lua"
#include "client/gameplay/time_sync.lua"
#include "client/gameplay/spectate.lua"
#include "client/gameplay/pregame.lua"
#include "client/gameplay/trail.lua"
#include "client/ui/admin_menu.lua"
#include "client/bootstrap/gamemode.lua"

#include "app/init.lua"

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

local impl = {
	serverInit = HS.srv and HS.srv.app and HS.srv.app.init or nil,
	clientInit = HS.cli and HS.cli.app and HS.cli.app.init or nil,
	publishShared = HS.srv and HS.srv.publishShared or nil,
}

if not (HS.arch and HS.arch.app and HS.arch.app.install) then
	error("HS architecture installer is missing")
end

HS.arch.app.install({
	initContext = initContext,
	impl = impl,
})
