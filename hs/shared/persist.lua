HS = HS or {}
HS.persist = HS.persist or {}

local P = HS.persist

local function engine()
	return HS.engine or {}
end

function P.has(key)
	local e = engine()
	if not e.hasKey then
		return nil
	end
	return e.hasKey(key)
end

function P.getFloat(key, default)
	local e = engine()
	local has = P.has(key)
	if has == false then return tonumber(default) or 0 end
	if e.getFloat then
		return tonumber(e.getFloat(key, default)) or (tonumber(default) or 0)
	end
	return tonumber(default) or 0
end

function P.getInt(key, default)
	local e = engine()
	local has = P.has(key)
	if has == false then return math.floor(tonumber(default) or 0) end
	if e.getInt then
		return math.floor(tonumber(e.getInt(key, default)) or (tonumber(default) or 0))
	end
	return math.floor(tonumber(default) or 0)
end

function P.getString(key, default)
	local e = engine()
	local has = P.has(key)
	if has == false then return tostring(default or "") end
	if e.getString then
		local s = tostring(e.getString(key, default) or "")
		if s == "" and default ~= nil then
			return tostring(default)
		end
		return s
	end
	return tostring(default or "")
end

function P.getBool(key, default)
	local e = engine()
	local has = P.has(key)
	if has == false then return default == true end
	if e.getBool then
		return e.getBool(key, default == true) == true
	end
	return P.getInt(key, default == true and 1 or 0) == 1
end

function P.setFloat(key, value)
	local e = engine()
	if not e.setFloat then return false end
	return e.setFloat(key, tonumber(value) or 0) == true
end

function P.setInt(key, value)
	local e = engine()
	if not e.setInt then return false end
	return e.setInt(key, math.floor(tonumber(value) or 0)) == true
end

function P.setString(key, value)
	local e = engine()
	if not e.setString then return false end
	return e.setString(key, tostring(value or "")) == true
end

function P.setBool(key, value)
	local e = engine()
	if e.setBool then
		return e.setBool(key, value == true) == true
	end
	return P.setInt(key, value == true and 1 or 0)
end

function P.ensureFloat(key, default)
	local has = P.has(key)
	if has == true then return P.getFloat(key, default) end
	if has == false then
		P.setFloat(key, default)
		return P.getFloat(key, default)
	end
	return P.getFloat(key, default)
end

function P.ensureInt(key, default)
	local has = P.has(key)
	if has == true then return P.getInt(key, default) end
	if has == false then
		P.setInt(key, default)
		return P.getInt(key, default)
	end
	return P.getInt(key, default)
end

function P.ensureString(key, default)
	local has = P.has(key)
	if has == true then return P.getString(key, default) end
	if has == false then
		P.setString(key, default)
		return P.getString(key, default)
	end
	return P.getString(key, default)
end

function P.ensureBool(key, default)
	local has = P.has(key)
	if has == true then return P.getBool(key, default) end
	if has == false then
		P.setBool(key, default)
		return P.getBool(key, default)
	end
	return P.getBool(key, default)
end

function P.ns(prefix)
	local ns = { prefix = tostring(prefix or "") }

	function ns.key(k) return ns.prefix .. tostring(k) end
	function ns.has(k) return P.has(ns.key(k)) end

	function ns.getFloat(k, default) return P.getFloat(ns.key(k), default) end
	function ns.getInt(k, default) return P.getInt(ns.key(k), default) end
	function ns.getString(k, default) return P.getString(ns.key(k), default) end
	function ns.getBool(k, default) return P.getBool(ns.key(k), default) end

	function ns.setFloat(k, v) return P.setFloat(ns.key(k), v) end
	function ns.setInt(k, v) return P.setInt(ns.key(k), v) end
	function ns.setString(k, v) return P.setString(ns.key(k), v) end
	function ns.setBool(k, v) return P.setBool(ns.key(k), v) end

	function ns.ensureFloat(k, v) return P.ensureFloat(ns.key(k), v) end
	function ns.ensureInt(k, v) return P.ensureInt(ns.key(k), v) end
	function ns.ensureString(k, v) return P.ensureString(ns.key(k), v) end
	function ns.ensureBool(k, v) return P.ensureBool(ns.key(k), v) end

	return ns
end
