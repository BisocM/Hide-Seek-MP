
HS = HS or {}
HS.persist = HS.persist or {}

local P = HS.persist

local function isFn(f) return type(f) == "function" end

function P.has(key)
	if not isFn(HasKey) then
		return nil
	end
	local ok, v = pcall(HasKey, key)
	return ok and v == true
end

local function safeGet(fn, key, default)
	if not isFn(fn) then return default end
	local has = P.has(key)
	if has == false then return default end
	local ok, v = pcall(fn, key)
	if ok and v ~= nil then return v end
	return default
end

function P.getFloat(key, default)
	return tonumber(safeGet(GetFloat, key, default)) or (tonumber(default) or 0)
end

function P.getInt(key, default)
	return math.floor(tonumber(safeGet(GetInt, key, default)) or (tonumber(default) or 0))
end

function P.getString(key, default)
	local v = safeGet(GetString, key, default)
	local s = tostring(v or "")
	if s == "" and default ~= nil then
		return tostring(default)
	end
	return s
end

function P.getBool(key, default)
	if isFn(GetBool) then
		local v = safeGet(GetBool, key, default == true)
		return v == true
	end
	return P.getInt(key, default == true and 1 or 0) == 1
end

local function safeSet(fn, key, value)
	if not isFn(fn) then return false end
	local ok = pcall(fn, key, value)
	return ok == true
end

function P.setFloat(key, value)
	return safeSet(SetFloat, key, tonumber(value) or 0)
end

function P.setInt(key, value)
	return safeSet(SetInt, key, math.floor(tonumber(value) or 0))
end

function P.setString(key, value)
	return safeSet(SetString, key, tostring(value or ""))
end

function P.setBool(key, value)
	if isFn(SetBool) then
		return safeSet(SetBool, key, value == true)
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
