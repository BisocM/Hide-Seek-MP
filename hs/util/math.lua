HS = HS or {}
HS.util = HS.util or {}
HS.util.math = HS.util.math or {}

local M = HS.util.math

function M.clamp(x, a, b)
	x = tonumber(x) or 0
	a = tonumber(a) or 0
	b = tonumber(b) or 0
	if x < a then return a end
	if x > b then return b end
	return x
end

if HS.util.clamp == nil then
	HS.util.clamp = M.clamp
end
