
HS = HS or {}
HS.engine = HS.engine or {}
local E = HS.engine

local function isFn(f) return type(f) == "function" end

function E.now()
	if isFn(GetTime) then
		local ok, t = pcall(GetTime)
		if ok then return t end
	end
	return 0
end

function E.timeStep()
	if isFn(GetTimeStep) then
		local ok, t = pcall(GetTimeStep)
		if ok then return t end
	end
	return 0
end

function E.languageId()
	if isFn(UiGetLanguage) then
		local ok, v = pcall(UiGetLanguage)
		if ok then
			return tonumber(v) or 0
		end
	end
	if isFn(GetInt) then
		local ok, v = pcall(GetInt, "options.language")
		if ok then
			return tonumber(v) or 0
		end
	end
	return 0
end

function E.isPlayerValid(playerId)
	return type(playerId) == "number" and playerId > 0 and isFn(IsPlayerValid) and IsPlayerValid(playerId)
end

function E.isPlayerHost(playerId)
	playerId = tonumber(playerId) or 0
	if playerId <= 0 or not isFn(IsPlayerHost) then
		return false
	end
	local ok, v = pcall(IsPlayerHost, playerId)
	return ok and v == true
end

function E.localPlayerId()
	if isFn(GetLocalPlayer) then
		local ok, pid = pcall(GetLocalPlayer)
		if ok then return tonumber(pid) or 0 end
	end
	return 0
end

function E.playerName(playerId)
	playerId = tonumber(playerId) or 0
	if playerId <= 0 then return "?" end
	if not isFn(GetPlayerName) then return "?" end
	local ok, name = pcall(GetPlayerName, playerId)
	if ok then
		local s = tostring(name or "")
		if s ~= "" and s ~= "?" and string.upper(s) ~= "UNKNOWN" then
			return s
		end
	end
	return "P" .. tostring(playerId)
end

function E.teamColor(teamId)
	if isFn(teamsGetColor) then
		local c = teamsGetColor(teamId)
		if type(c) == "table" then
			return c
		end
	end
	return { 1, 1, 1, 1 }
end

function E.inputPressed(action)
	if not isFn(InputPressed) then return false end
	local ok, v = pcall(InputPressed, action)
	return ok and v == true
end

function E.lastPressedKey()
	if not isFn(InputLastPressedKey) then return "" end
	local ok, v = pcall(InputLastPressedKey)
	if ok and type(v) == "string" then return v end
	return ""
end

function E.pauseMenuButton(label, area, disabled)
	if not isFn(PauseMenuButton) then return false end
	local ok, v = pcall(PauseMenuButton, label, area, disabled)
	return ok and v == true
end

function E.uiHasImage(path)
	if not isFn(UiHasImage) then return false end
	local ok, v = pcall(UiHasImage, path)
	return ok and v == true
end

function E.uiGetImageSize(path)
	if not isFn(UiGetImageSize) then return 0, 0 end
	local ok, w, h = pcall(UiGetImageSize, path)
	if ok then
		return tonumber(w) or 0, tonumber(h) or 0
	end
	return 0, 0
end

function E.uiSound(path)
	if not isFn(UiSound) then return false end
	return pcall(UiSound, path) == true
end

function E.playerCameraTransform(playerId)
	if not isFn(GetPlayerCameraTransform) then return nil end
	if playerId == nil then
		local ok, tr = pcall(GetPlayerCameraTransform)
		return ok and tr or nil
	end
	local ok, tr = pcall(GetPlayerCameraTransform, playerId)
	return ok and tr or nil
end

function E.setCameraTransform(tr)
	if not isFn(SetCameraTransform) then return false end
	return pcall(SetCameraTransform, tr) == true
end

function E.clientCall(targetPlayerId, fnName, ...)
	if not isFn(ClientCall) then return false end
	return pcall(ClientCall, targetPlayerId, fnName, ...) == true
end

local _warnedUnknownServerCall = {}

local function callServerLiteral(fnName, ...)
	if not isFn(ServerCall) then return false end

	if fnName == "server.hs_command" then
		local playerId, envelope = ...
		ServerCall("server.hs_command", playerId, envelope)
		return true
	end

	if _warnedUnknownServerCall[fnName] ~= true then
		_warnedUnknownServerCall[fnName] = true
		if HS.log and HS.log.warn then
			HS.log.warn("Blocked dynamic server call target", { fnName = tostring(fnName or "") })
		end
	end
	return false
end

function E.serverCall(fnName, ...)
	return callServerLiteral(fnName, ...)
end

function E.hasKey(key)
	if not isFn(HasKey) then return nil end
	local ok, v = pcall(HasKey, key)
	if not ok then return nil end
	return v == true
end

function E.listKeys(prefix)
	if not isFn(ListKeys) then return nil end
	local ok, v = pcall(ListKeys, prefix)
	if not ok or type(v) ~= "table" then return nil end
	return v
end

function E.getFloat(key, default)
	if not isFn(GetFloat) then return tonumber(default) or 0 end
	local ok, v = pcall(GetFloat, key)
	if ok and v ~= nil then
		return tonumber(v) or (tonumber(default) or 0)
	end
	return tonumber(default) or 0
end

function E.getInt(key, default)
	if not isFn(GetInt) then return math.floor(tonumber(default) or 0) end
	local ok, v = pcall(GetInt, key)
	if ok and v ~= nil then
		return math.floor(tonumber(v) or (tonumber(default) or 0))
	end
	return math.floor(tonumber(default) or 0)
end

function E.getString(key, default)
	if not isFn(GetString) then return tostring(default or "") end
	local ok, v = pcall(GetString, key)
	if ok and v ~= nil then
		return tostring(v)
	end
	return tostring(default or "")
end

function E.getBool(key, default)
	if isFn(GetBool) then
		local ok, v = pcall(GetBool, key)
		if ok and v ~= nil then return v == true end
	end
	return default == true
end

function E.setFloat(key, value)
	if not isFn(SetFloat) then return false end
	return pcall(SetFloat, key, tonumber(value) or 0) == true
end

function E.setInt(key, value)
	if not isFn(SetInt) then return false end
	return pcall(SetInt, key, math.floor(tonumber(value) or 0)) == true
end

function E.setString(key, value)
	if not isFn(SetString) then return false end
	return pcall(SetString, key, tostring(value or "")) == true
end

function E.setBool(key, value)
	if not isFn(SetBool) then return false end
	return pcall(SetBool, key, value == true) == true
end

local function clearArray(t)
	for i = #t, 1, -1 do
		t[i] = nil
	end
end

function E.playersSorted(ctx)
	local cache = (ctx and ctx.cache) or nil
	if not cache then
		local ids = {}
		if isFn(Players) then
			for p in Players() do
				ids[#ids + 1] = p
			end
		elseif isFn(GetAllPlayers) then
			local tmp = GetAllPlayers() or {}
			for i = 1, #tmp do
				ids[#ids + 1] = tmp[i]
			end
		end
		table.sort(ids)
		return ids
	end

	local frame = ctx.frame or 0
	if cache._playersSortedFrame == frame and cache._playersSorted then
		return cache._playersSorted
	end

	local ids = cache._playersSorted or {}
	clearArray(ids)
	if isFn(Players) then
		for p in Players() do
			ids[#ids + 1] = p
		end
	elseif isFn(GetAllPlayers) then
		local tmp = GetAllPlayers() or {}
		for i = 1, #tmp do
			ids[#ids + 1] = tmp[i]
		end
	end
	table.sort(ids)

	cache._playersSorted = ids
	cache._playersSortedFrame = frame
	return ids
end
