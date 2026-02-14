HS = HS or {}
HS.infra = HS.infra or {}
HS.infra.snapshot = HS.infra.snapshot or {}

local W = HS.infra.snapshot

W._revision = W._revision or 0
W.VERSION = W.VERSION or 1
W.SCHEMA = W.SCHEMA or ((HS.contracts and HS.contracts.schemas and HS.contracts.schemas.SNAPSHOT_SCHEMA) or "hs.snapshot.v1")

local function logError(msg, data)
	if HS.log and HS.log.error then
		HS.log.error(msg, data)
	end
end

local function copySettings(settings)
	if HS.util and HS.util.deepcopy then
		return HS.util.deepcopy(settings or {})
	end
	return settings or {}
end

local function collectAbilityMaps(state)
	local readyAt = {}
	local armedUntil = {}
	local ids = HS.domain.model.sortedPlayerIds(state)
	for i = 1, #ids do
		local pid = ids[i]
		local p = state.players[pid]
		if p and type(p.abilities) == "table" then
			for abilityId, ab in pairs(p.abilities) do
				abilityId = tostring(abilityId or "")
				if abilityId ~= "" then
					readyAt[abilityId] = readyAt[abilityId] or {}
					armedUntil[abilityId] = armedUntil[abilityId] or {}
					readyAt[abilityId][pid] = tonumber(ab and ab.readyAt) or 0
					armedUntil[abilityId][pid] = tonumber(ab and ab.armedUntil) or 0
				end
			end
		end
	end
	return readyAt, armedUntil
end

local function buildSnapshot(state, serverNow)
	local players = {
		teamOf = {},
		readyOf = {},
		outOf = {},
	}

	for _, pid in ipairs(HS.domain.model.sortedPlayerIds(state)) do
		local p = state.players[pid]
		if p then
			players.teamOf[pid] = tonumber(p.team) or 0
			players.readyOf[pid] = p.ready == true
			players.outOf[pid] = p.out == true
		end
	end

	local seekers = HS.domain.model.countAlive(state, HS.const.TEAM_SEEKERS)
	local hiders = HS.domain.model.countAlive(state, HS.const.TEAM_HIDERS)
	local readyAt, armedUntil = collectAbilityMaps(state)

	W._revision = (tonumber(W._revision) or 0) + 1

	return {
		meta = {
			version = W.VERSION,
			schema = W.SCHEMA,
			revision = W._revision,
			serverNow = tonumber(serverNow) or 0,
		},
		match = {
			phase = tostring(state.phase or HS.const.PHASE_SETUP),
			phaseEndsAt = tonumber(state.phaseEndsAt) or 0,
			round = tonumber(state.round) or 0,
			lastWinner = tostring(state.lastWinner or ""),
			matchActive = state.matchActive == true,
			scoreSeekers = tonumber(state.scoreSeekers) or 0,
			scoreHiders = tonumber(state.scoreHiders) or 0,
			hidersRemaining = hiders,
			seekersCount = seekers,
		},
		players = players,
		abilities = {
			readyAt = readyAt,
			armedUntil = armedUntil,
		},
		settings = copySettings(state.settings),
			uiHints = {
				gameIsSetup = tostring(state.phase or "") ~= HS.const.PHASE_SETUP,
				taggingEnabled = state.settings and state.settings.taggingEnabled == true,
				tagOnlyMode = state.settings and state.settings.tagOnlyMode == true,
				setupState = tostring(state.setupState or "waiting"),
				setupEndsAt = tonumber(state.setupEndsAt) or 0,
			},
		}
	end

function W.reset()
	W._revision = 0
end

function W.write(state, serverNow)
	if type(state) ~= "table" then return false end
	local sh = buildSnapshot(state, serverNow)
	local validate = HS.contracts and HS.contracts.validate
	if validate and validate.snapshot then
		local ok, err = validate.snapshot(sh)
		if not ok then
			logError("Snapshot validation failed", { reason = tostring(err) })
			return false
		end
	end
	shared.hs = sh
	return true
end
