
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
	if not E.isPlayerValid(playerId) then return "?" end
	if not isFn(GetPlayerName) then return "?" end
	local ok, name = pcall(GetPlayerName, playerId)
	if ok then
		local s = tostring(name or "")
		if s ~= "" then return s end
	end
	return "?"
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

E.serverRpc = E.serverRpc or {}
local SR = E.serverRpc

function SR.hsStart(playerId, settings)
	if not isFn(ServerCall) then return false end
	ServerCall("server.hs_start", playerId, settings)
	return true
end

function SR.requestTag(playerId)
	if not isFn(ServerCall) then return false end
	ServerCall("server.hs_requestTag", playerId)
	return true
end

function SR.ability(playerId, abilityId, event)
	if not isFn(ServerCall) then return false end
	ServerCall("server.hs_ability", playerId, abilityId, event)
	return true
end

function SR.triggerSuperjump(playerId)
	if not isFn(ServerCall) then return false end
	ServerCall("server.hs_triggerSuperjump", playerId)
	return true
end

function SR.timeSync(playerId, seq, clientSentAt)
	if not isFn(ServerCall) then return false end
	ServerCall("server.hs_timeSync", playerId, seq, clientSentAt)
	return true
end

function SR.updateLoadout(playerId, loadout)
	if not isFn(ServerCall) then return false end
	ServerCall("server.hs_updateLoadout", playerId, loadout)
	return true
end

function SR.teamsJoinTeam(playerId, teamId)
	if not isFn(ServerCall) then return false end
	ServerCall("server._teamsJoinTeam", playerId, teamId)
	return true
end

function SR.hudPlayPressed(playerId, settings)
	if not isFn(ServerCall) then return false end
	ServerCall("server.hudPlayPressed", playerId, settings)
	return true
end

function SR.unstuck(playerId)
	if not isFn(ServerCall) then return false end
	ServerCall("server._unstuck", playerId)
	return true
end

-- Compatibility adapter: preserve old callsites but route to literal-name RPC methods.
function E.serverCall(fnName, ...)
	fnName = tostring(fnName or "")
	if fnName == "server.hs_start" then
		return SR.hsStart(...)
	elseif fnName == "server.hs_requestTag" then
		return SR.requestTag(...)
	elseif fnName == "server.hs_ability" then
		return SR.ability(...)
	elseif fnName == "server.hs_triggerSuperjump" then
		return SR.triggerSuperjump(...)
	elseif fnName == "server.hs_timeSync" then
		return SR.timeSync(...)
	elseif fnName == "server.hs_updateLoadout" then
		return SR.updateLoadout(...)
	elseif fnName == "server._teamsJoinTeam" then
		return SR.teamsJoinTeam(...)
	elseif fnName == "server.hudPlayPressed" then
		return SR.hudPlayPressed(...)
	elseif fnName == "server._unstuck" then
		return SR.unstuck(...)
	end
	return false
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
