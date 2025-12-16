
HS = HS or {}
HS.log = HS.log or {}

local LEVELS = {
	error = 1,
	warn = 2,
	info = 3,
	debug = 4,
}

HS.log.levels = HS.log.levels or LEVELS
HS.log.level = HS.log.level or LEVELS.info

local function emit(line)
	if type(DebugPrint) == "function" then
		DebugPrint(line)
	else
		print(line)
	end
end

local function toLevel(level)
	if type(level) == "number" then
		return level
	end
	if type(level) == "string" then
		return LEVELS[string.lower(level)] or LEVELS.info
	end
	return LEVELS.info
end

function HS.log.setLevel(level)
	HS.log.level = toLevel(level)
end

local function dumpOne(v)
	local tv = type(v)
	if tv == "string" then return string.format("%q", v) end
	if tv == "number" or tv == "boolean" then return tostring(v) end
	if tv == "nil" then return "nil" end
	if tv == "table" then return "<table>" end
	return "<" .. tv .. ">"
end

function HS.log.dump(v)
	if type(v) ~= "table" then
		return dumpOne(v)
	end
	local parts = {}
	local n = 0
	for k, vv in pairs(v) do
		n = n + 1
		if n > 10 then
			parts[#parts + 1] = "…"
			break
		end
		parts[#parts + 1] = tostring(k) .. "=" .. dumpOne(vv)
	end
	return "{" .. table.concat(parts, ", ") .. "}"
end

function HS.log._write(levelName, message, data)
	local levelNum = toLevel(levelName)
	if levelNum > (HS.log.level or LEVELS.info) then return end

	local msg = tostring(message or "")
	if data ~= nil then
		msg = msg .. " " .. HS.log.dump(data)
	end
	emit(string.format("[HS][%s] %s", tostring(levelName), msg))
end

function HS.log.error(message, data) HS.log._write("error", message, data) end
function HS.log.warn(message, data) HS.log._write("warn", message, data) end
function HS.log.info(message, data) HS.log._write("info", message, data) end
function HS.log.debug(message, data) HS.log._write("debug", message, data) end

