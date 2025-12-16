
HS = HS or {}
HS.ctx = HS.ctx or {}
HS.use = HS.use or {}

local _ctx = nil

---@class HSContext
---@field side string
---@field frame number
---@field now number
---@field dt number
---@field cache table
---@field services table

local function ensureCtx()
	_ctx = _ctx or { side = "unknown", frame = 0, now = 0, dt = 0, cache = {}, services = {} }
	_ctx.cache = _ctx.cache or {}
	_ctx.services = _ctx.services or {}
	return _ctx
end

function HS.ctx.get()
	return _ctx
end

function HS.ctx.init(side)
	local ctx = ensureCtx()
	if side ~= nil then
		ctx.side = tostring(side)
	end
	return ctx
end

function HS.ctx.set(name, service)
	local ctx = ensureCtx()
	ctx.services[name] = service
	ctx[name] = service
	return service
end

function HS.ctx.service(name)
	local ctx = _ctx
	return ctx and ctx.services and ctx.services[name] or nil
end

function HS.use.ctx()
	return _ctx
end

function HS.use.log()
	local ctx = _ctx
	return (ctx and ctx.log) or HS.log
end

function HS.use.i18n()
	local ctx = _ctx
	return (ctx and ctx.i18n) or HS.i18n
end

function HS.use.settings()
	local ctx = _ctx
	return (ctx and ctx.settings) or HS.settings
end

function HS.use.persist()
	local ctx = _ctx
	return (ctx and ctx.persist) or HS.persist
end

function HS.use.engine()
	local ctx = _ctx
	return (ctx and ctx.engine) or HS.engine
end

function HS.use.select()
	local ctx = _ctx
	return (ctx and ctx.select) or HS.select
end

function HS.use.ui()
	local ctx = _ctx
	return (ctx and ctx.ui) or HS.ui
end

function HS.use.telemetry()
	local ctx = _ctx
	return (ctx and ctx.telemetry) or HS.telemetry
end
