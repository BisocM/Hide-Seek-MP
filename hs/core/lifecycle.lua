
HS = HS or {}
HS.lifecycle = HS.lifecycle or {}

local function systemName(sys, idx)
	if type(sys) == "table" and sys.name then
		return tostring(sys.name)
	end
	return tostring(idx)
end

function HS.lifecycle.run(ctx, systems, method, ...)
	if not systems then return end
	for i = 1, #systems do
		local sys = systems[i]
		local fn = sys and sys[method]
		if type(fn) == "function" then
			local ok, err = pcall(fn, sys, ctx, ...)
			if not ok then
				local log = (ctx and ctx.log) or HS.log
				if log and log.error then
					log.error("System error: " .. systemName(sys, i) .. "." .. tostring(method), { err = err })
				end
			end
		end
	end
end

