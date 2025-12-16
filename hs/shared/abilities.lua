
HS = HS or {}
HS.abilities = HS.abilities or {}

local A = HS.abilities

A.ids = A.ids or {
	dash = "dash",
	superjump = "superjump",
}

A._defs = A._defs or {}
A._order = A._order or {}
A._list = nil

local function indexOf(list, v)
	for i = 1, #list do
		if list[i] == v then return i end
	end
	return nil
end

function A.register(def)
	if type(def) ~= "table" then return false end
	local id = tostring(def.id or "")
	if id == "" then return false end

	def.id = id
	A._defs[id] = def
	if not indexOf(A._order, id) then
		A._order[#A._order + 1] = id
	end
	A._list = nil
	return true
end

if type(A._pendingDefs) == "table" then
	local pending = A._pendingDefs
	A._pendingDefs = nil
	for i = 1, #pending do
		A.register(pending[i])
	end
end

function A.def(id)
	return A._defs[tostring(id or "")]
end

function A.list()
	if A._list then return A._list end

	local out = {}
	for _, id in ipairs(A._order) do
		local def = A._defs[id]
		if def then
			out[#out + 1] = def
		end
	end

	table.sort(out, function(a, b)
		local sa = tonumber(a.slot or (a.ui and a.ui.slot)) or 999
		local sb = tonumber(b.slot or (b.ui and b.ui.slot)) or 999
		if sa ~= sb then return sa < sb end
		local ia = indexOf(A._order, tostring(a.id)) or 999
		local ib = indexOf(A._order, tostring(b.id)) or 999
		if ia ~= ib then return ia < ib end
		return tostring(a.id) < tostring(b.id)
	end)

	A._list = out
	return out
end

function A.cooldownLeft(now, readyAt)
	now = tonumber(now) or 0
	readyAt = tonumber(readyAt) or 0
	return math.max(0, readyAt - now)
end

function A.isArmed(now, armedUntil)
	now = tonumber(now) or 0
	armedUntil = tonumber(armedUntil) or 0
	return armedUntil > 0 and now < armedUntil
end

#include "abilities/dash.lua"
#include "abilities/superjump.lua"
