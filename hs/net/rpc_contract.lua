HS = HS or {}
HS.net = HS.net or {}
HS.net.contract = HS.net.contract or {}

local C = HS.net.contract

local function normalizeAbilityPayload(payload)
	if type(payload) ~= "table" then
		return nil
	end
	local abilityId = tostring(payload.abilityId or "")
	local event = tostring(payload.event or "use")
	if abilityId == "" then
		return nil
	end
	return { abilityId = abilityId, event = event }
end

local function normalizeTimeSyncPayload(payload)
	if type(payload) ~= "table" then
		return nil
	end
	return {
		seq = tonumber(payload.seq) or 0,
		clientSentAt = tonumber(payload.clientSentAt) or 0,
	}
end

local function normalizeLoadoutPayload(payload)
	if HS.loadout and HS.loadout.normalize then
		return HS.loadout.normalize(payload or {})
	end
	return type(payload) == "table" and payload or { enabled = false, tools = {}, assign = {} }
end

local function normalizeTeamJoinPayload(payload)
	if type(payload) ~= "table" then
		return nil
	end
	local teamId = tonumber(payload.teamId) or 0
	teamId = math.floor(teamId)
	if teamId < 0 then
		teamId = 0
	end
	return { teamId = teamId }
end

local function normalizeStartSettings(payload)
	local inSettings = type(payload) == "table" and payload or {}
	local base = (HS.settings and HS.settings.defaults and HS.settings.defaults()) or nil
	local out = (HS.settings and HS.settings.normalize and HS.settings.normalize(inSettings, base)) or inSettings

	if HS.loadout and HS.loadout.normalize then
		out.loadout = HS.loadout.normalize(inSettings.loadout or {}, out.loadout)
	end
	return out
end

function C.parse(name, playerId, payload)
	name = tostring(name or "")
	playerId = tonumber(playerId) or 0
	if playerId <= 0 then
		return nil, "invalid playerId"
	end

	if name == "start" then
		return { kind = "start", playerId = playerId, settings = normalizeStartSettings(payload) }
	elseif name == "requestTag" then
		return { kind = "requestTag", playerId = playerId }
	elseif name == "ability" then
		local ab = normalizeAbilityPayload(payload)
		if not ab then
			return nil, "invalid ability payload"
		end
		return { kind = "ability", playerId = playerId, abilityId = ab.abilityId, event = ab.event }
	elseif name == "timeSync" then
		local ts = normalizeTimeSyncPayload(payload)
		if not ts then
			return nil, "invalid timeSync payload"
		end
		return { kind = "timeSync", playerId = playerId, seq = ts.seq, clientSentAt = ts.clientSentAt }
	elseif name == "updateLoadout" then
		return { kind = "updateLoadout", playerId = playerId, loadout = normalizeLoadoutPayload(payload) }
	elseif name == "teamsJoinTeam" then
		local tj = normalizeTeamJoinPayload(payload)
		if not tj then
			return nil, "invalid teamsJoinTeam payload"
		end
		return { kind = "teamsJoinTeam", playerId = playerId, teamId = tj.teamId }
	end

	return nil, "unknown command"
end
