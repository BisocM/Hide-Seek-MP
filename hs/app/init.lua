HS = HS or {}
HS.app = HS.app or {}

HS.app.server = HS.app.server or {}
HS.app.client = HS.app.client or {}

local function beginFrame(side, dt)
	local ctx = HS.ctx and HS.ctx.init and HS.ctx.init(side) or nil
	if ctx then
		ctx.log = HS.log
		ctx.telemetry = HS.telemetry
		ctx.engine = HS.engine
		ctx.persist = HS.persist
		ctx.i18n = HS.i18n
		ctx.settings = HS.settings
	end
	if HS.runtime and HS.runtime.beginFrame then
		HS.runtime.beginFrame(ctx, dt)
	end
	return ctx
end

function HS.app.server.init()
	beginFrame("server", 0)
	if HS.app.serverRuntime and HS.app.serverRuntime.init then
		HS.app.serverRuntime.init()
	end
end

function HS.app.server.tick(dt)
	beginFrame("server", dt)
	if HS.app.serverRuntime and HS.app.serverRuntime.tick then
		HS.app.serverRuntime.tick(dt)
	end
end

function HS.app.client.init()
	beginFrame("client", 0)
	if HS.app.clientRuntime and HS.app.clientRuntime.init then
		HS.app.clientRuntime.init()
	end
	if HS.presentation and HS.presentation.client and HS.presentation.client.runtime and HS.presentation.client.runtime.init then
		HS.presentation.client.runtime.init()
	end
end

function HS.app.client.tick(dt)
	local ctx = beginFrame("client", dt)
	if HS.app.clientRuntime and HS.app.clientRuntime.tick then
		HS.app.clientRuntime.tick(dt, ctx)
	end
	if HS.presentation and HS.presentation.client and HS.presentation.client.runtime and HS.presentation.client.runtime.tick then
		HS.presentation.client.runtime.tick(dt, ctx)
	end
end

function HS.app.client.draw()
	local dt = HS.engine and HS.engine.timeStep and HS.engine.timeStep() or 0
	local ctx = beginFrame("client", dt)
	if HS.presentation and HS.presentation.client and HS.presentation.client.runtime and HS.presentation.client.runtime.draw then
		HS.presentation.client.runtime.draw(ctx)
	end
end
