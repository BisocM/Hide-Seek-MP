HS = HS or {}
HS.net = HS.net or {}
HS.net.client = HS.net.client or {}

local N = HS.net.client

N.handlers = N.handlers or {}

function N.init()
	N.handlers = N.handlers or {}
end

function N.register(name, fn)
	name = tostring(name or "")
	if name == "" or type(fn) ~= "function" then
		return false
	end
	N.handlers[name] = fn
	return true
end

function N.dispatch(name, ...)
	local fn = N.handlers and N.handlers[tostring(name or "")]
	if type(fn) ~= "function" then return false end
	return pcall(fn, ...)
end
