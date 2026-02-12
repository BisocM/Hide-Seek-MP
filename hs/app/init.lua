#include "../domain/types.lua"
#include "../domain/events.lua"
#include "../domain/match/service.lua"
#include "../domain/teams/service.lua"
#include "../domain/combat/service.lua"
#include "../domain/tagging/service.lua"
#include "../domain/abilities/service.lua"
#include "../domain/loadout/service.lua"

#include "../adapters/teardown/server_api.lua"
#include "../adapters/teardown/client_api.lua"

#include "../net/rpc_contract.lua"
#include "../net/client_handlers.lua"
#include "../net/server_handlers.lua"

#include "../state/snapshot.lua"

#include "../systems/server/common.lua"
#include "../systems/server/stages/command_ingress.lua"
#include "../systems/server/stages/teams_setup.lua"
#include "../systems/server/stages/players_roster.lua"
#include "../systems/server/stages/loadout.lua"
#include "../systems/server/stages/lobby_guard.lua"
#include "../systems/server/stages/rules_pre.lua"
#include "../systems/server/stages/round.lua"
#include "../systems/server/stages/abilities.lua"
#include "../systems/server/stages/rules_post.lua"
#include "../systems/server/stages/snapshot_publish.lua"

#include "../systems/client/common.lua"
#include "../systems/client/tick/hud_tick.lua"
#include "../systems/client/tick/admin_tick.lua"
#include "../systems/client/tick/time_sync_tick.lua"
#include "../systems/client/tick/trail_tick.lua"
#include "../systems/client/tick/abilities_tick.lua"
#include "../systems/client/tick/spectate_tick.lua"
#include "../systems/client/tick/tag_input_tick.lua"
#include "../systems/client/draw/camera_draw.lua"
#include "../systems/client/draw/scene_draw.lua"
#include "../systems/client/draw/abilities_draw.lua"
#include "../systems/client/draw/feed_draw.lua"
#include "../systems/client/draw/toast_draw.lua"
#include "../systems/client/draw/banner_draw.lua"
#include "../systems/client/draw/admin_draw.lua"

#include "../ui/viewmodels/match.lua"
#include "../ui/scenes/setup.lua"
#include "../ui/scenes/match.lua"
#include "../ui/widgets/panel.lua"

HS = HS or {}
HS.arch = HS.arch or {}
HS.arch.app = HS.arch.app or {}

local function runPipeline(ctx, pipeline, method, dt)
	for i = 1, #pipeline do
		local sys = pipeline[i]
		local fn = sys and sys[method]
		if type(fn) == "function" then
			local ok, stopOrErr = pcall(fn, sys, ctx, dt)
			if not ok and HS.log and HS.log.error then
				HS.log.error("Pipeline system failed", {
					system = tostring(sys.name or i),
					method = tostring(method),
					err = tostring(stopOrErr),
				})
			elseif stopOrErr == true then
				break
			end
		end
	end
end

local function buildImpl(opts)
	local impl = (type(opts.impl) == "table") and opts.impl or nil
	if type(impl) ~= "table" then
		error("Missing required architecture implementation table")
	end

	if type(impl.serverInit) ~= "function" then
		error("Missing required server init implementation")
	end
	if type(impl.clientInit) ~= "function" then
		error("Missing required client init implementation")
	end
	if type(impl.publishShared) ~= "function" then
		error("Missing required snapshot publish implementation")
	end

	return impl
end

function HS.arch.app.install(opts)
	opts = opts or {}
	local initContext = opts.initContext
	local impl = buildImpl(opts)
	if type(initContext) ~= "function" then
		error("Missing required initContext implementation")
	end

	HS.arch.impl = impl

	if not (HS.state and HS.state.snapshot and HS.state.snapshot.installSyncSource) then
		error("Snapshot source installer is missing")
	end
	HS.state.snapshot.installSyncSource(impl.publishShared)

	HS.arch.serverPipeline = {
		HS.systems.server.commandIngress,
		HS.systems.server.teamsSetup,
		HS.systems.server.playersRoster,
		HS.systems.server.loadout,
		HS.systems.server.lobbyGuard,
		HS.systems.server.rulesPre,
		HS.systems.server.round,
		HS.systems.server.abilities,
		HS.systems.server.rulesPost,
		HS.systems.server.snapshotPublish,
	}

	HS.arch.clientTickPipeline = {
		HS.systems.client.hudTick,
		HS.systems.client.adminTick,
		HS.systems.client.timeSyncTick,
		HS.systems.client.trailTick,
		HS.systems.client.abilitiesTick,
		HS.systems.client.spectateTick,
		HS.systems.client.tagInputTick,
	}

	HS.arch.clientDrawPipeline = {
		HS.systems.client.cameraDraw,
		HS.systems.client.sceneDraw,
		HS.systems.client.abilitiesDraw,
		HS.systems.client.feedDraw,
		HS.systems.client.toastDraw,
		HS.systems.client.bannerDraw,
		HS.systems.client.adminDraw,
	}

	local function frame(side, dt)
		local ctx = initContext(side)

		if ctx then
			ctx.adapters = ctx.adapters or {}
			ctx.adapters.server = HS.adapters and HS.adapters.server or nil
			ctx.adapters.client = HS.adapters and HS.adapters.client or nil
			ctx.viewmodels = HS.ui and HS.ui.viewmodels or nil
		end

		if HS.runtime and HS.runtime.beginFrame then
			HS.runtime.beginFrame(ctx, dt)
		end
		return ctx
	end

	HS.app.server.init = function()
		frame("server", 0)
		if HS.net and HS.net.server and HS.net.server.init then
			HS.net.server.init()
		end
		if type(impl.serverInit) == "function" then
			impl.serverInit()
		end
		if HS.state and HS.state.snapshot and HS.state.snapshot.touch then
			HS.state.snapshot.touch()
		end
	end

	HS.app.server.tick = function(dt)
		local ctx = frame("server", dt)
		runPipeline(ctx, HS.arch.serverPipeline or {}, "tick", dt)
	end

	HS.app.client.init = function()
		frame("client", 0)
		if HS.net and HS.net.client and HS.net.client.init then
			HS.net.client.init()
		end
		if type(impl.clientInit) == "function" then
			impl.clientInit()
		end
	end

	HS.app.client.tick = function(dt)
		local ctx = frame("client", dt)
		runPipeline(ctx, HS.arch.clientTickPipeline or {}, "tick", dt)
	end

	HS.app.client.draw = function()
		local dt = HS.engine and HS.engine.timeStep and HS.engine.timeStep() or 0
		local ctx = frame("client", dt)
		runPipeline(ctx, HS.arch.clientDrawPipeline or {}, "draw", dt)
	end
end
