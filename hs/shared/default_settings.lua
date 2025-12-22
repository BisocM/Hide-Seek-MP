HS = HS or {}
HS.defaults = HS.defaults or {}

function HS.defaults.make()
	if HS.settings and HS.settings.defaults then
		return HS.settings.defaults()
	end

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
