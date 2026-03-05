--- Teams

#include "script/include/player.lua"

HS = HS or {}
HS.srv = HS.srv or {}

local function hsT(key, params)
	if HS and HS.t then
		return HS.t(key, params)
	end
	return tostring(key)
end

local function hsText(text, params)
	if type(text) == "string" and string.sub(text, 1, 3) == "hs." then
		return hsT(text, params)
	end
	return tostring(text or "")
end

local function requestTeamJoin(teamId)
	local localId = (HS.engine and HS.engine.localPlayerId and HS.engine.localPlayerId()) or GetLocalPlayer()
	if HS.app and HS.app.commands and HS.app.commands.teamJoin then
		HS.app.commands.teamJoin(teamId, localId)
	end
end

_WAITING = 1
_COUNTDOWN = 2
_LOCKED = 3
_DONE = 4

_COUNTDOWNTIME = 3.0
_LOCKTIME = 2.5

_teamState = { time=0.0, pendingTeamSwaps = {}, stateTime = 0.0, skippedCountdown = false }
client._teamState = { stateTime = 0.0, prevState = _WAITING }

local function ensureSharedTeamState()
	if type(shared) ~= "table" then
		return nil
	end
	if type(shared._teamState) ~= "table" then
		shared._teamState = { teams = {}, state = _WAITING, maxDiff = 1 }
	end
	local st = shared._teamState
	st.teams = type(st.teams) == "table" and st.teams or {}
	for i = 1, 2 do
		st.teams[i] = type(st.teams[i]) == "table" and st.teams[i] or {}
		if st.teams[i].name == nil then
			st.teams[i].name = (i == 1) and "hs.team.seekers" or "hs.team.hiders"
		end
		if type(st.teams[i].color) ~= "table" then
			if i == 1 then
				st.teams[i].color = { 0.8, 0.25, 0.2, 1 }
			else
				st.teams[i].color = { 0.2, 0.55, 0.8, 1 }
			end
		end
		st.teams[i].players = type(st.teams[i].players) == "table" and st.teams[i].players or {}
	end
	if st.state == nil then st.state = _WAITING end
	if st.maxDiff == nil then st.maxDiff = 1 end
	return st
end

--- Initialize the team system with a given number of teams (server).
function teamsInit(teamCount)
    shared._teamState = { teams={}, state = _WAITING, maxDiff = nil }
    for i=1,teamCount do
        shared._teamState.teams[1 + #shared._teamState.teams] = { 
            name=_teamsGetDefaultTeamName(i), 
            color=_teamsGetDefaultColor(i),
            players={}
        }
    end
end

--- Get the configured color for a team.
function teamsGetColor(teamId)
	local st = ensureSharedTeamState()
	if not st or st.teams[teamId] == nil then
		return _teamsGetDefaultColor(teamId)
	end
	return st.teams[teamId].color
end

--- Set custom colors for all teams (server).
function teamsSetColors(colors)
    for i=1,#shared._teamState.teams do
        shared._teamState.teams[i].color = colors[i]
    end
end

--- Set custom names for all teams (server).
function teamsSetNames(names)
    for i=1,#shared._teamState.teams do
        shared._teamState.teams[i].name = names[i]
    end
end

--- Set the maximum allowed difference between the largest and smallest team sizes (server).
function teamsSetMaxDiff(maxDiff)
    if shared._teamState == nil then return end
    if maxDiff == nil then
        shared._teamState.maxDiff = nil
        return
    end
    shared._teamState.maxDiff = math.max(0, tonumber(maxDiff) or 0)
end

--- Get the configured team name for a given team ID.
function teamsGetName(teamId)
	local st = ensureSharedTeamState()
	if not st or st.teams[teamId] == nil then
		return _teamsGetDefaultTeamName(teamId)
	end
	return st.teams[teamId].name
end

--- Assign players to teams directly (server).
function teamsSetTeams(teams)
    local teamCount = #teams

    for i=1,teamCount do
        shared._teamState.teams[i].players = teams[i]
    end
end

--- Returns a lookup table mapping each player to their team ID.
function teamsGetPlayerTeamsList()
    local playerTeamList = {}

    for p in Players() do
        playerTeamList[p] = teamsGetTeamId(p)
    end

    return playerTeamList
end

--- Get the list of players belonging to a specific team.
function teamsGetTeamPlayers(teamId)
	local st = ensureSharedTeamState()
	if not st or st.teams[teamId] == nil then
		return {}
	end
	return st.teams[teamId].players
end

--- Returns a lookup table mapping each player ID to their current team color.
function teamsGetPlayerColorsList()
    local playerColorList = {}
    
    for p in Players() do
        local team = teamsGetTeamId(p)
        playerColorList[p] = teamsGetColor(team)
    end

    return playerColorList
end

--- Start the match or begin the team selection countdown (server).
function teamsStart(skipCountdown)
    if skipCountdown then
        shared._teamState.state = _DONE
        _teamState.skippedCountdown = true
        _teamsAssignPlayers()
    else
        if shared._teamState.state == _WAITING then
            shared._teamState.state = _COUNTDOWN
            _teamState.stateTime = 0.0
        end
    end
end

--- Check if team setup is complete and the match has started.
function teamsIsSetup()
	local st = ensureSharedTeamState()
	return st ~= nil and st.state == _DONE
end

--- Get the team ID of a specific player.
function teamsGetTeamId(playerId)
	local st = ensureSharedTeamState()
	if not st then return 0 end
	for i = 1, #st.teams do
		for p = 1, #st.teams[i].players do
			if st.teams[i].players[p] == playerId then
				return i
			end
		end
	end
	return 0
end

--- Tick team logic (server).
function teamsTick(dt)

    _teamState.stateTime = _teamState.stateTime + dt
        
    for p in PlayersRemoved() do
        for t=1,#shared._teamState.teams do
            local players = shared._teamState.teams[t].players
            for i=1,#players do
                if players[i] == p then
                    table.remove(players, i)
                    break
                end
            end
        end
    end

    if shared._teamState.state == _DONE then
        for p in PlayersAdded() do
            _teamsAssignPlayers()
        end

        for p in Players() do
            local team = teamsGetTeamId(p)
            local color = teamsGetColor(team)
            SetPlayerColor(color[1], color[2], color[3], p)
        end
    end
    
    for i=1,#_teamState.pendingTeamSwaps do
        local playerId = _teamState.pendingTeamSwaps[i][1]
        local teamId = _teamState.pendingTeamSwaps[i][2]
        for i=1,#shared._teamState.teams do
            for p=1, #shared._teamState.teams[i].players do
                if shared._teamState.teams[i].players[p] == playerId then
                    table.remove(shared._teamState.teams[i].players, p)
                    break
                end
            end
        end

        if teamId > 0 then
            local players = shared._teamState.teams[teamId].players
            players[1 + #players] = playerId
        end
    end
    _teamState.pendingTeamSwaps = {}

    if shared._teamState.state == _DONE and _teamState.skippedCountdown then
        _teamState.skippedCountdown = false
        return true
    end

    if shared._teamState.state == _COUNTDOWN then
        if _teamState.stateTime > _COUNTDOWNTIME then
            shared._teamState.state = _LOCKED
            _teamState.stateTime = 0.0
            _teamsAssignPlayers()
        end
    end

    if shared._teamState.state == _LOCKED then
        if _teamState.stateTime > _LOCKTIME then
            shared._teamState.state = _DONE
            _teamState.stateTime = 0.0
            PostEvent("teamsupdated", teamsGetPlayerTeamsList(), teamsGetPlayerColorsList())
            return true
        end
    end

    return false
end


--- Get a list of players on the same team as the local player (client).
function teamsGetLocalTeam()
    local team = {}
    local teamId = teamsGetTeamId(GetLocalPlayer())
	for p in Players() do
		if teamsGetTeamId(p) == teamId then
			team[1 + #team] = p
		end
	end

    return team
end


--- Render the team selection screen UI (client).
function teamsDraw(dt)
	local st = ensureSharedTeamState()
	if not st then return end
	if st.state == _DONE then return end

    client._teamState.stateTime = client._teamState.stateTime + dt

    if client._teamState.prevState ~= st.state then
        client._teamState.prevState = st.state
        client._teamState.stateTime = 0.0
    end

    _teamState.time = _teamState.time + dt
    local cam = VecScale(Vec(math.sin(_teamState.time*0.025), 1.0, math.cos(_teamState.time*0.025)), 50.0)
    SetCameraTransform(Transform(cam, QuatLookAt(cam, Vec())))
	SetCameraDof(0, 0)

    UiMakeInteractive()
    SetBool("game.disablemap", true)

    UiPush()
        UiAlign("left top")
        UiColor(0, 0, 0, 1)
        UiRect(UiWidth(), UiHeight())
    UiPop()

    local teamCount = #st.teams

    local teamBoxWidth = 292
    local teamBoxHeight = 376

    local width = 10 + teamBoxWidth * teamCount + 10 * (teamCount-1) + 10
    local height = 432

    UiPush()
        UiAlign("left top")
        UiTranslate(UiCenter() - width/2, UiMiddle() - height/2)
        uiDrawPanel(width, height, 16)

        UiTranslate(0,10)

        UiPush()
            UiTranslate(width/2, 0)
            UiColor(COLOR_WHITE)
            UiFont("bold.ttf", 32 * 1.23)
            UiAlign("center top")
            UiText(hsT("hs.ui.teams.title"))
        UiPop()

        UiTranslate(0, 36)

        UiPush()
        UiTranslate(10,0)
        for i = 1, teamCount do
            _teamsDrawTeamBox(i, teamBoxWidth, teamBoxHeight)
            UiTranslate(teamBoxWidth + 10,0)
        end
        UiPop()
    UiPop()

    UiPush()

    local hintY = math.max(80, UiMiddle() - height * 0.5 - 48)
    UiTranslate(UiCenter(), hintY)
    if st.state >= _LOCKED then
        uiDrawTextPanel(hsT("hs.ui.teams.starting"), 1)
    elseif st.state >= _COUNTDOWN then
        local text = hsT("hs.ui.teams.lockingIn")

        if teamsGetTeamId(GetLocalPlayer()) == 0 then
            text = hsT("hs.ui.teams.autoAssigningIn")
        end

        uiDrawTextPanel(text.." "..clamp(math.ceil(_COUNTDOWNTIME - client._teamState.stateTime), 0.0, _COUNTDOWNTIME), 1)
    end

    UiPop()
end


function _teamsWouldExceedMaxDiff(playerId, teamId)
    local maxDiff = shared._teamState.maxDiff
    if maxDiff == nil then return false end
    if teamId == 0 then return false end

    local teamCount = #shared._teamState.teams
    if teamCount <= 1 then return false end

    local counts = {}
    local assigned = 0
    for t=1,teamCount do
        counts[t] = #shared._teamState.teams[t].players
        assigned = assigned + (counts[t] or 0)
    end

    local currentTeam = teamsGetTeamId(playerId)
    if currentTeam > 0 then
        counts[currentTeam] = math.max(0, (counts[currentTeam] or 0) - 1)
        assigned = math.max(0, assigned - 1)
    end
    if teamId > 0 then
        counts[teamId] = (counts[teamId] or 0) + 1
        assigned = assigned + 1
    end

    local minCount = 999999
    local maxCount = -999999
    for t=1,teamCount do
        minCount = math.min(minCount, counts[t] or 0)
        maxCount = math.max(maxCount, counts[t] or 0)
    end

    local diff = (maxCount - minCount)
    if diff <= maxDiff then
        return false
    end

    local totalPlayers = 0
    for _p in Players() do
        totalPlayers = totalPlayers + 1
    end
    local unassigned = math.max(0, totalPlayers - assigned)

    local targetMin = maxCount - maxDiff
    local required = 0
    for t=1,teamCount do
        local need = targetMin - (counts[t] or 0)
        if need > 0 then
            required = required + need
        end
    end

    return required > unassigned
end

function HS.srv.queueTeamJoin(playerId, teamId)
    playerId = tonumber(playerId) or 0
    teamId = tonumber(teamId) or 0
    if playerId <= 0 then
        return false
    end
    if teamId < 0 then
        teamId = 0
    end

    if shared._teamState.state and shared._teamState.state >= _LOCKED then
        return false
    end

    local teamCount = #shared._teamState.teams
    if teamId > teamCount then
        return false
    end

    if teamId > 0 and _teamsWouldExceedMaxDiff(playerId, teamId) then
        return false
    end

    _teamState.pendingTeamSwaps[1 + #_teamState.pendingTeamSwaps] = { playerId, teamId }
    return true
end

function _teamsAssignPlayers()
    for p in Players() do
        if teamsGetTeamId(p) == 0 then
            local chosenTeam = 0
            local minCount = 999

            for t=1,#shared._teamState.teams do
                local count = #shared._teamState.teams[t].players
                if count < minCount and not _teamsWouldExceedMaxDiff(p, t) then
                    minCount = count
                    chosenTeam = t
                end
            end

            if chosenTeam > 0 then
                local players = shared._teamState.teams[chosenTeam].players
                players[1 + #players] = p
            end
        end
    end

    local teamColors = {}
    for i=1,#shared._teamState.teams do
        teamColors[1 + #teamColors] = teamsGetColor(i)
    end

    PostEvent("teamsupdated", teamsGetPlayerTeamsList(), teamColors)
end

function _teamsDrawTeamBox(teamId, width, height)
    UiPush()
        
        local players = shared._teamState.teams[teamId].players;

        local teamName = hsText(shared._teamState.teams[teamId].name)
        local color = shared._teamState.teams[teamId].color
        local bgCol = color

        UiColor(bgCol[1], bgCol[2], bgCol[3])
        UiRoundedRectOutline(width, height, 12, 4)

        UiTranslate(8,8)
        UiRoundedRect(width - 2 * 8, 36, 4)
        
        UiFont("bold.ttf", 32)
        UiColor(COLOR_WHITE)
        UiPush()
            UiTranslate((width - 2 * 8)/2, 18)
            UiAlign("center middle")
            UiText(teamName)
        UiPop()

        UiTranslate(0, 36 + 4)

        UiAlign("left middle")

        UiTranslate(0, 32/2)

        for i=1,#players do
            
            UiPush()
            
            local isLocalPlayer = players[i] == GetLocalPlayer()
            
            if isLocalPlayer then
                UiColor(1,1,1,0.2)
            else
                UiColor(1,1,1,0.1)
            end
            
            UiRoundedRect(width - 2 * 8, 32, 4)

            UiPush()
            UiTranslate(0, -32/2)
            uiDrawPlayerRow(players[i], 32,width - 2 * 8, bgCol)
            UiPop()
            
            UiPop()
            
            UiTranslate(0, 32 + 2)
        end

        for i = 1, 8 - #players do
            UiColor(1,1,1,0.1)
            UiRoundedRect(width - 2 * 8, 32, 4)
            UiTranslate(0, 32 + 2)
        end

        UiTranslate(0, 10)

        UiFont(FONT_BOLD, FONT_SIZE_20)

        local team = teamsGetTeamId(GetLocalPlayer())
        if team == teamId then
            if uiDrawSecondaryButton(hsT("hs.ui.teams.leave"), width - 2 * 8, shared._teamState.state and shared._teamState.state >= _LOCKED) then
                requestTeamJoin(0)
            end
        else
            local locked = shared._teamState.state and shared._teamState.state >= _LOCKED
            local tooImbalanced = _teamsWouldExceedMaxDiff(GetLocalPlayer(), teamId)

            if uiDrawSecondaryButton(hsT("hs.ui.teams.join"), width - 2 * 8, team ~= 0 or locked or tooImbalanced) then
                requestTeamJoin(teamId)
            end
        end
    UiPop()
end

function _teamsGetDefaultColor(teamIndex)
    if teamIndex == 1 then
        return COLOR_TEAM_2
    elseif teamIndex == 2 then
        return COLOR_TEAM_1
    elseif teamIndex == 3 then
        return COLOR_TEAM_3
    elseif teamIndex == 4 then
        return COLOR_TEAM_4
    end

    return COLOR_WHITE
end

function _teamsGetDefaultTeamName(teamId)
    if teamId == 1 then
        return "Team A"
    elseif teamId == 2 then
        return "Team B"
    elseif teamId == 3 then
        return "Team C"
    elseif teamId == 4 then
        return "Team D"
    end
    return "Team X"
end
