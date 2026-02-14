HS = HS or {}
HS.loadout = HS.loadout or {}

local L = HS.loadout

L.ASSIGN_OFF = 0
L.ASSIGN_SEEKERS = 1
L.ASSIGN_HIDERS = 2
L.ASSIGN_BOTH = 3

L._basegameTools = L._basegameTools or {
	-- Mirrors what Teardown exposes under `game.tool.*` in a default sandbox install,
	-- plus a few commonly-present extras. Discovery should still find the real set.
	"sledge",
	"spraycan",
	"extinguisher",
	"blowtorch",
	"shotgun",
	"plank",
	"pipebomb",
	"gun",
	"bomb",
	"rocket",
	"leafblower",
	"rifle",
	"wire",
	"booster",
	"turbo",
	"steroid",
	"explosive",
}

local function safeHasKey(key)
	if HS.engine and HS.engine.hasKey then
		return HS.engine.hasKey(key) == true
	end
	return false
end

local function safeListKeys(prefix)
	if HS.engine and HS.engine.listKeys then
		local v = HS.engine.listKeys(prefix)
		if type(v) == "table" then
			return v
		end
	end
	return nil
end

local function safeGetString(key, default)
	if HS.engine and HS.engine.getString then
		local s = tostring(HS.engine.getString(key, default) or "")
		if s ~= "" then
			return s
		end
	end
	return default
end

local function encodeCsv(list)
	if type(list) ~= "table" or #list == 0 then return "" end
	return table.concat(list, ",")
end

local function decodeCsv(s)
	s = tostring(s or "")
	if s == "" then return {} end
	local out = {}
	for part in string.gmatch(s, "([^,]+)") do
		part = tostring(part or "")
		if part ~= "" then
			out[#out + 1] = part
		end
	end
	return out
end

local function makeSet(list)
	local set = {}
	for i = 1, #list do
		set[list[i]] = true
	end
	return set
end

L._basegameSet = L._basegameSet or makeSet(L._basegameTools)

function L.savePrefix()
	local p = (HS.settings and HS.settings.savePrefix) or "savegame.mod.settings.hs."
	return p .. "loadout."
end

function L.clampAssign(v)
	v = math.floor(tonumber(v) or 0)
	if v < 0 then return 0 end
	if v > 3 then return 3 end
	return v
end

function L.defaultAssignFor(toolId)
	toolId = tostring(toolId or "")
	if toolId == "" then return L.ASSIGN_OFF end
	if L._basegameSet and L._basegameSet[toolId] then
		return L.ASSIGN_BOTH
	end
	return L.ASSIGN_OFF
end

function L.allowed(assign, teamId)
	assign = L.clampAssign(assign)
	teamId = tonumber(teamId) or 0
	if assign == L.ASSIGN_BOTH then return true end
	if assign == L.ASSIGN_SEEKERS then return teamId == (HS.const and HS.const.TEAM_SEEKERS) end
	if assign == L.ASSIGN_HIDERS then return teamId == (HS.const and HS.const.TEAM_HIDERS) end
	return false
end

local function isToolLeaf(path)
	-- The `.enabled` key is what we enforce against. If it doesn't exist, we can't safely toggle.
	return safeHasKey(path .. ".enabled")
end

function L.discoverToolInfo()
	-- Returns { { id=string, name=string, index=number|nil }, ... }
	local out = {}

	local top = safeListKeys("game.tool")
	if type(top) ~= "table" then
		return out
	end

	for i = 1, #top do
		local seg = tostring(top[i] or "")
		if seg ~= "" then
			local path = "game.tool." .. seg
			if isToolLeaf(path) then
				out[#out + 1] = {
					id = seg,
					name = safeGetString(path .. ".name", seg),
					index = tonumber(safeGetString(path .. ".index", "")),
				}
			else
				-- Best-effort: support one extra level for mods that namespace tools as `game.tool.<mod>.<tool>`.
				local sub = safeListKeys(path)
				if type(sub) == "table" then
					for j = 1, #sub do
						local s2 = tostring(sub[j] or "")
						if s2 ~= "" then
							local subPath = path .. "." .. s2
							if isToolLeaf(subPath) then
								local id = seg .. "." .. s2
								out[#out + 1] = {
									id = id,
									name = safeGetString(subPath .. ".name", id),
									index = tonumber(safeGetString(subPath .. ".index", "")),
								}
							end
						end
					end
				end
			end
		end
	end

	table.sort(out, function(a, b)
		local ai = a and a.index
		local bi = b and b.index
		if ai ~= nil and bi ~= nil then
			if ai == bi then
				return tostring(a.id or "") < tostring(b.id or "")
			end
			return ai < bi
		end
		if ai ~= nil then return true end
		if bi ~= nil then return false end
		return tostring(a.id or "") < tostring(b.id or "")
	end)

	return out
end

function L.discoverTools()
	local info = L.discoverToolInfo()
	if type(info) == "table" and #info > 0 then
		local ids = {}
		for i = 1, #info do
			ids[#ids + 1] = info[i].id
		end
		return ids
	end

	-- Fallback: return a conservative baseline.
	local ids = {}
	for i = 1, #L._basegameTools do
		ids[#ids + 1] = L._basegameTools[i]
	end
	return ids
end

function L.normalize(input, base)
	base = base or { enabled = false, tools = {}, assign = {} }
	input = input or {}

	local out = {
		enabled = (input.enabled == true) or (base.enabled == true and input.enabled ~= false),
		tools = {},
		assign = {},
	}

	local seen = {}
	local tools = (type(input.tools) == "table") and input.tools or ((type(base.tools) == "table") and base.tools or {})
	for i = 1, #tools do
		local id = tostring(tools[i] or "")
		if id ~= "" and not seen[id] then
			seen[id] = true
			out.tools[#out.tools + 1] = id
		end
	end

	local assignIn = (type(input.assign) == "table") and input.assign or ((type(base.assign) == "table") and base.assign or {})
	for i = 1, #out.tools do
		local id = out.tools[i]
		local v = assignIn[id]
		if v == nil then
			v = L.defaultAssignFor(id)
		end
		out.assign[id] = L.clampAssign(v)
	end

	return out
end

function L.readPersist(persist, opts)
	opts = opts or {}
	local discoverIfMissing = opts.discoverIfMissing == true

	local P = persist or HS.persist
	if not P or not P.ns then
		return L.normalize({})
	end

	local ns = P.ns(L.savePrefix())
	local enabled = (ns.getInt("enabled", 0) or 0) == 1

	local tools = decodeCsv(ns.getString("tools", ""))
	if #tools == 0 and discoverIfMissing then
		tools = L.discoverTools()
	end

	-- If not enabled and we don't have an explicit tool list, avoid discovery here.
	if #tools == 0 then
		return L.normalize({ enabled = enabled, tools = {}, assign = {} })
	end

	local assign = {}
	for i = 1, #tools do
		local id = tools[i]
		local v = ns.getInt("assign." .. id, -999)
		if v == -999 then
			v = L.defaultAssignFor(id)
		end
		assign[id] = L.clampAssign(v)
	end

	return L.normalize({ enabled = enabled, tools = tools, assign = assign })
end

function L.writePersist(persist, loadout)
	local P = persist or HS.persist
	if not P or not P.ns then return false end

	local normalized = L.normalize(loadout or {})
	local ns = P.ns(L.savePrefix())

	ns.setInt("enabled", normalized.enabled and 1 or 0)
	ns.setString("tools", encodeCsv(normalized.tools))

	for i = 1, #normalized.tools do
		local id = normalized.tools[i]
		ns.setInt("assign." .. id, normalized.assign[id] or L.defaultAssignFor(id))
	end

	return true
end
