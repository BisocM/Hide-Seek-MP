
HS = HS or {}
HS.settings = HS.settings or {}

local S = HS.settings

S.savePrefix = S.savePrefix or "savegame.mod.settings.hs."

function S.defaults()
	return {
		hideSeconds = 20,
		seekSeconds = 300,
		intermissionSeconds = 10,
		roundsToPlay = 5,
		infectionMode = true,
		swapTeamsEachRound = true,
		maxTeamDiff = 1,
		seekerGraceSeconds = 5,
		tagRangeMeters = 4.0,
		taggingEnabled = true,
		tagOnlyMode = false,
		allowHidersKillSeekers = false,
		hiderAbilitiesEnabled = true,
		healthRegenEnabled = true,
		hiderTrailEnabled = true,
		seekerMapEnabled = false,
		requireAllReady = false,
	}
end

local function clamp(v, a, b)
	return HS.util.clamp(tonumber(v) or 0, a, b)
end

local function readNumber(ns, key, default)
	if ns and ns.getString then
		local s = ns.getString(key, nil)
		local n = tonumber(s)
		if n ~= nil then return n end
	end
	if ns and ns.getFloat then
		return tonumber(ns.getFloat(key, default)) or (tonumber(default) or 0)
	end
	return tonumber(default) or 0
end

local function readBool01(ns, key, default)
	if ns and ns.getString then
		local s = ns.getString(key, nil)
		if s ~= nil and s ~= "" then
			s = tostring(s)
			if s == "1" or s == "true" or s == "TRUE" or s == "True" then return true end
			if s == "0" or s == "false" or s == "FALSE" or s == "False" then return false end
		end
	end
	if ns and ns.getBool then
		return ns.getBool(key, default == true)
	end
	if ns and ns.getInt then
		return ns.getInt(key, default == true and 1 or 0) == 1
	end
	return default == true
end

function S.normalize(input, base)
	base = base or S.defaults()
	input = input or {}

	local out = {
		hideSeconds = clamp(input.hideSeconds or base.hideSeconds, 20, 180),
		seekSeconds = clamp(input.seekSeconds or base.seekSeconds, 5 * 60, 1800),
		intermissionSeconds = clamp(input.intermissionSeconds or base.intermissionSeconds, 10, 60),
		roundsToPlay = clamp(input.roundsToPlay or base.roundsToPlay, 0, 100),
		infectionMode = (input.infectionMode == true),
		swapTeamsEachRound = (input.swapTeamsEachRound == true),
		maxTeamDiff = clamp(input.maxTeamDiff or base.maxTeamDiff, 0, 10),
		seekerGraceSeconds = clamp(input.seekerGraceSeconds or base.seekerGraceSeconds, 5, 20),
		tagRangeMeters = clamp(input.tagRangeMeters or base.tagRangeMeters, 1.0, 20.0),
		taggingEnabled = (input.taggingEnabled == true),
		tagOnlyMode = (input.tagOnlyMode == true),
		allowHidersKillSeekers = (input.allowHidersKillSeekers == true),
		hiderAbilitiesEnabled = (input.hiderAbilitiesEnabled ~= false),
		healthRegenEnabled = (input.healthRegenEnabled == true),
		hiderTrailEnabled = (input.hiderTrailEnabled == true),
		seekerMapEnabled = (input.seekerMapEnabled == true),
		requireAllReady = (input.requireAllReady == true),
	}

	if out.tagOnlyMode then
		out.taggingEnabled = true
		out.allowHidersKillSeekers = false
	end

	return out
end

function S.schema()
	local lang = "en"
	if HS and HS.i18n and type(HS.i18n.detect) == "function" then
		local ok, v = pcall(HS.i18n.detect)
		if ok and type(v) == "string" and v ~= "" then
			lang = v
		end
	end

	if S._schema and S._schemaLang == lang then
		return S._schema
	end

	local p = S.savePrefix
	local t = HS and HS.t or function(key) return tostring(key) end
	S._schema = {
		{
			title = t("hs.settings.group.round"),
			items = {
				{ key = p .. "hideSeconds", label = t("hs.settings.hideSeconds.label"), info = t("hs.settings.hideSeconds.info"), options = { { label = "00:20", value = 20 }, { label = "00:30", value = 30 }, { label = "00:45", value = 45 }, { label = "01:00", value = 60 }, { label = "01:15", value = 75 }, { label = "01:30", value = 90 } } },
				{ key = p .. "seekSeconds", label = t("hs.settings.seekSeconds.label"), info = t("hs.settings.seekSeconds.info"), options = { { label = "05:00", value = 300 }, { label = "07:00", value = 420 }, { label = "10:00", value = 600 }, { label = "12:00", value = 720 }, { label = "15:00", value = 900 }, { label = "20:00", value = 1200 } } },
				{ key = p .. "intermissionSeconds", label = t("hs.settings.intermissionSeconds.label"), info = t("hs.settings.intermissionSeconds.info"), options = { { label = "00:10", value = 10 }, { label = "00:15", value = 15 }, { label = "00:20", value = 20 }, { label = "00:30", value = 30 } } },
				{ key = p .. "roundsToPlay", label = t("hs.settings.roundsToPlay.label"), info = t("hs.settings.roundsToPlay.info"), options = { { label = t("hs.common.infinite"), value = 0 }, { label = "3", value = 3 }, { label = "5", value = 5 }, { label = "7", value = 7 }, { label = "10", value = 10 } } },
			},
		},
		{
			title = t("hs.settings.group.teams"),
			items = {
				{ key = p .. "infectionMode", label = t("hs.settings.infectionMode.label"), info = t("hs.settings.infectionMode.info"), options = { { label = t("hs.common.on"), value = 1 }, { label = t("hs.common.off"), value = 0 } } },
				{ key = p .. "swapTeamsEachRound", label = t("hs.settings.swapTeamsEachRound.label"), info = t("hs.settings.swapTeamsEachRound.info"), options = { { label = t("hs.common.on"), value = 1 }, { label = t("hs.common.off"), value = 0 } } },
				{ key = p .. "maxTeamDiff", label = t("hs.settings.maxTeamDiff.label"), info = t("hs.settings.maxTeamDiff.info"), options = { { label = "0", value = 0 }, { label = "1", value = 1 }, { label = "2", value = 2 }, { label = "3", value = 3 } } },
			},
		},
		{
			title = t("hs.settings.group.tagging"),
			items = {
				{ key = p .. "taggingEnabled", label = t("hs.settings.taggingEnabled.label"), info = t("hs.settings.taggingEnabled.info"), options = { { label = t("hs.common.on"), value = 1 }, { label = t("hs.common.off"), value = 0 } } },
				{ key = p .. "tagOnlyMode", label = t("hs.settings.tagOnlyMode.label"), info = t("hs.settings.tagOnlyMode.info"), options = { { label = t("hs.common.off"), value = 0 }, { label = t("hs.common.on"), value = 1 } } },
				{ key = p .. "tagRangeMeters", label = t("hs.settings.tagRangeMeters.label"), info = t("hs.settings.tagRangeMeters.info"), options = { { label = "3m", value = 3.0 }, { label = "4m", value = 4.0 }, { label = "5m", value = 5.0 }, { label = "6m", value = 6.0 } } },
			},
		},
		{
			title = t("hs.settings.group.gameplay"),
			items = {
				{ key = p .. "seekerGraceSeconds", label = t("hs.settings.seekerGraceSeconds.label"), info = t("hs.settings.seekerGraceSeconds.info"), options = { { label = "5s", value = 5 }, { label = "7s", value = 7 }, { label = "10s", value = 10 } } },
				{ key = p .. "allowHidersKillSeekers", label = t("hs.settings.allowHidersKillSeekers.label"), info = t("hs.settings.allowHidersKillSeekers.info"), options = { { label = t("hs.common.off"), value = 0 }, { label = t("hs.common.on"), value = 1 } } },
				{ key = p .. "hiderAbilitiesEnabled", label = t("hs.settings.hiderAbilitiesEnabled.label"), info = t("hs.settings.hiderAbilitiesEnabled.info"), options = { { label = t("hs.common.on"), value = 1 }, { label = t("hs.common.off"), value = 0 } } },
				{ key = p .. "healthRegenEnabled", label = t("hs.settings.healthRegenEnabled.label"), info = t("hs.settings.healthRegenEnabled.info"), options = { { label = t("hs.common.on"), value = 1 }, { label = t("hs.common.off"), value = 0 } } },
				{ key = p .. "hiderTrailEnabled", label = t("hs.settings.hiderTrailEnabled.label"), info = t("hs.settings.hiderTrailEnabled.info"), options = { { label = t("hs.common.on"), value = 1 }, { label = t("hs.common.off"), value = 0 } } },
				{ key = p .. "seekerMapEnabled", label = t("hs.settings.seekerMapEnabled.label"), info = t("hs.settings.seekerMapEnabled.info"), options = { { label = t("hs.common.off"), value = 0 }, { label = t("hs.common.on"), value = 1 } } },
			},
		},
	}
	S._schemaLang = lang
	return S._schema
end

function S.ensureSavegameDefaults(persist)
	local P = persist or HS.persist
	if not P or not P.ns then return end

	local d = S.defaults()
	local ns = P.ns(S.savePrefix)

	ns.ensureFloat("hideSeconds", d.hideSeconds)
	ns.ensureFloat("seekSeconds", d.seekSeconds)
	ns.ensureFloat("intermissionSeconds", d.intermissionSeconds)
	ns.ensureFloat("roundsToPlay", d.roundsToPlay)
	ns.ensureInt("infectionMode", d.infectionMode and 1 or 0)
	ns.ensureInt("swapTeamsEachRound", d.swapTeamsEachRound and 1 or 0)
	ns.ensureFloat("maxTeamDiff", d.maxTeamDiff)
	local grace = ns.ensureFloat("seekerGraceSeconds", d.seekerGraceSeconds)
	if (tonumber(grace) or 0) < 5 then
		ns.setFloat("seekerGraceSeconds", 5)
	end
	ns.ensureFloat("tagRangeMeters", d.tagRangeMeters)
	ns.ensureInt("taggingEnabled", d.taggingEnabled and 1 or 0)
	ns.ensureInt("tagOnlyMode", d.tagOnlyMode and 1 or 0)
	ns.ensureInt("allowHidersKillSeekers", d.allowHidersKillSeekers and 1 or 0)
	ns.ensureInt("hiderAbilitiesEnabled", d.hiderAbilitiesEnabled and 1 or 0)
	ns.ensureInt("healthRegenEnabled", d.healthRegenEnabled and 1 or 0)
	ns.ensureInt("hiderTrailEnabled", d.hiderTrailEnabled and 1 or 0)
	ns.ensureInt("seekerMapEnabled", d.seekerMapEnabled and 1 or 0)
	ns.ensureInt("requireAllReady", d.requireAllReady and 1 or 0)
end

function S.readHostStartPayload(persist)
	local P = persist or HS.persist
	if not P or not P.ns then return S.normalize({}, S.defaults()) end

	local d = S.defaults()
	local ns = P.ns(S.savePrefix)

	return {
		hideSeconds = readNumber(ns, "hideSeconds", d.hideSeconds),
		seekSeconds = readNumber(ns, "seekSeconds", d.seekSeconds),
		intermissionSeconds = readNumber(ns, "intermissionSeconds", d.intermissionSeconds),
		roundsToPlay = readNumber(ns, "roundsToPlay", d.roundsToPlay),
		infectionMode = readBool01(ns, "infectionMode", d.infectionMode),
		swapTeamsEachRound = readBool01(ns, "swapTeamsEachRound", d.swapTeamsEachRound),
		maxTeamDiff = readNumber(ns, "maxTeamDiff", d.maxTeamDiff),
		seekerGraceSeconds = readNumber(ns, "seekerGraceSeconds", d.seekerGraceSeconds),
		tagRangeMeters = readNumber(ns, "tagRangeMeters", d.tagRangeMeters),
		taggingEnabled = readBool01(ns, "taggingEnabled", d.taggingEnabled),
		tagOnlyMode = readBool01(ns, "tagOnlyMode", d.tagOnlyMode),
		allowHidersKillSeekers = readBool01(ns, "allowHidersKillSeekers", d.allowHidersKillSeekers),
		hiderAbilitiesEnabled = readBool01(ns, "hiderAbilitiesEnabled", d.hiderAbilitiesEnabled),
		healthRegenEnabled = readBool01(ns, "healthRegenEnabled", d.healthRegenEnabled),
		hiderTrailEnabled = readBool01(ns, "hiderTrailEnabled", d.hiderTrailEnabled),
		seekerMapEnabled = readBool01(ns, "seekerMapEnabled", d.seekerMapEnabled),
		requireAllReady = readBool01(ns, "requireAllReady", d.requireAllReady),
	}
end
