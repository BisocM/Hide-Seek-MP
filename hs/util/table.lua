HS = HS or {}
HS.util = HS.util or {}
HS.util.table = HS.util.table or {}

local Tbl = HS.util.table

function Tbl.appendAll(dst, src)
	dst = type(dst) == "table" and dst or {}
	src = type(src) == "table" and src or {}
	for i = 1, #src do
		dst[#dst + 1] = src[i]
	end
	return dst
end

function Tbl.clearArray(arr)
	if type(arr) ~= "table" then
		return
	end
	for i = #arr, 1, -1 do
		arr[i] = nil
	end
end

function Tbl.clearMap(map)
	if type(map) ~= "table" then
		return
	end
	for k in pairs(map) do
		map[k] = nil
	end
end

function Tbl.shallowCopy(src)
	local out = {}
	for k, v in pairs(type(src) == "table" and src or {}) do
		out[k] = v
	end
	return out
end

function Tbl.mergeFields(base, extra)
	local out = Tbl.shallowCopy(base)
	for k, v in pairs(type(extra) == "table" and extra or {}) do
		out[k] = v
	end
	return out
end
