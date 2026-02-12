
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

function E.isPlayerValid(playerId)
	return type(playerId) == "number" and playerId > 0 and isFn(IsPlayerValid) and IsPlayerValid(playerId)
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

function E.serverCall(fnName, ...)
	if not isFn(ServerCall) then return false end
	return pcall(ServerCall, fnName, ...) == true
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
