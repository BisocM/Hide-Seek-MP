HS = HS or {}
HS.i18n = HS.i18n or {}

local I = HS.i18n

I.defaultLanguage = I.defaultLanguage or "en"
I.language = I.language or nil

I.detect = I.detect or function()
	local langId = nil
	if type(UiGetLanguage) == "function" then
		local ok, v = pcall(UiGetLanguage)
		if ok then langId = tonumber(v) end
	end
	if langId == nil and type(GetInt) == "function" then
		local ok, v = pcall(GetInt, "options.language")
		if ok then langId = tonumber(v) end
	end
	langId = math.floor(langId or 0)

	if langId == 7 then return "ru" end
	return "en"
end

I.strings = I.strings or {
	en = {
		["hs.title"] = "Hide & Seek",

		["hs.common.on"] = "On",
		["hs.common.off"] = "Off",
		["hs.common.infinite"] = "Infinite",

		["hs.phase.setup"] = "Setup",
		["hs.phase.hiding"] = "Hiding",
		["hs.phase.seeking"] = "Seeking",
		["hs.phase.intermission"] = "Intermission",

		["hs.role.seeker"] = "SEEKER",
		["hs.role.hider"] = "HIDER",
		["hs.role.spectator"] = "SPECTATOR",

		["hs.team.seekers"] = "Seekers",
		["hs.team.hiders"] = "Hiders",

		["hs.status.playing"] = "Playing",
		["hs.status.spectating"] = "Spectating",

		["hs.toast.welcome"] = "Welcome. Choose a team.",
		["hs.toast.lateJoin"] = "Match in progress. You'll join next round.",
		["hs.toast.needPlayersPerTeam"] = "Need at least 2 players (1 per team).",
		["hs.toast.notEnoughPlayers"] = "Not enough players to continue.",
		["hs.toast.hideStarted"] = "Hide phase started!",
		["hs.toast.seekStarted"] = "Seek phase started!",
		["hs.toast.roundOver"] = "Round over.",
		["hs.toast.matchComplete"] = "Match complete. Returning to setup.",

		["hs.toast.taggingOffEliminate"] = "Tagging is off. Eliminate hiders to catch.",
		["hs.toast.noHiderInRange"] = "No hider in range.",

		["hs.ui.pickRole.tagPrompt"] = "Press E to tag",
		["hs.ui.pickRole.eliminatePrompt"] = "Eliminate to catch",
		["hs.ui.action.tag"] = "Tag",

		["hs.ui.hostMenu.title"] = "Host Menu",
		["hs.ui.hostMenu.settings"] = "Game Mode Settings",
		["hs.ui.hostMenu.start"] = "Start",

		["hs.ui.adminMenu.title"] = "Admin Menu",
		["hs.ui.adminMenu.pauseButton"] = "HS Admin",
		["hs.ui.adminMenu.close"] = "Close",
		["hs.ui.adminMenu.enforcement"] = "Loadout enforcement",
		["hs.ui.adminMenu.refreshTools"] = "Refresh tools",
		["hs.ui.adminMenu.disableAll"] = "Disable all",
		["hs.ui.adminMenu.seekersOnly"] = "Seekers only",
		["hs.ui.adminMenu.hidersOnly"] = "Hiders only",
		["hs.ui.adminMenu.both"] = "Both",
		["hs.ui.adminMenu.weaponsTitle"] = "Tools & Weapons",
		["hs.ui.loadout.both"] = "Both",

		["hs.ui.settings.title"] = "GAME MODE SETTINGS",
		["hs.ui.settings.resetDefaults"] = "Reset to defaults",
		["hs.ui.settings.close"] = "Close",

		["hs.ui.teams.title"] = "Join a team",
		["hs.ui.teams.starting"] = "Starting...",
		["hs.ui.teams.lockingIn"] = "Locking teams in",
		["hs.ui.teams.autoAssigningIn"] = "Auto assigning teams in",
		["hs.ui.teams.join"] = "Join",
		["hs.ui.teams.leave"] = "Leave",

		["hs.settings.group.round"] = "Round",
		["hs.settings.group.rules"] = "Rules",
		["hs.settings.group.teams"] = "Teams",
		["hs.settings.group.tagging"] = "Tagging",
		["hs.settings.group.gameplay"] = "Gameplay",

		["hs.settings.hideSeconds.label"] = "Hiding time",
		["hs.settings.hideSeconds.info"] = "How long seekers are locked/blinded at round start.",
		["hs.settings.seekSeconds.label"] = "Seeking time",
		["hs.settings.seekSeconds.info"] = "Time limit for seekers to find everyone.",
		["hs.settings.intermissionSeconds.label"] = "Intermission",
		["hs.settings.intermissionSeconds.info"] = "Break between rounds.",
		["hs.settings.roundsToPlay.label"] = "Rounds",
		["hs.settings.roundsToPlay.info"] = "Number of rounds to play (0 = infinite).",

		["hs.settings.infectionMode.label"] = "Infection mode",
		["hs.settings.infectionMode.info"] = "Tagged hiders become seekers (instead of being eliminated).",
		["hs.settings.swapTeamsEachRound.label"] = "Swap roles each round",
		["hs.settings.swapTeamsEachRound.info"] = "Swap seekers/hiders between rounds.",
		["hs.settings.maxTeamDiff.label"] = "Max team difference",
		["hs.settings.maxTeamDiff.info"] = "Limit team stacking (0 = perfectly even).",
		["hs.settings.seekerGraceSeconds.label"] = "Seeker grace",
		["hs.settings.seekerGraceSeconds.info"] = "Invulnerability for seekers after seeking starts (prevents instant trap kills when hiders can kill seekers).",
		["hs.settings.tagRangeMeters.label"] = "Tag range",
		["hs.settings.tagRangeMeters.info"] = "Max distance for seeker tagging interaction.",
		["hs.settings.taggingEnabled.label"] = "Tagging",
		["hs.settings.taggingEnabled.info"] = "If disabled, seekers must eliminate hiders by damage (no E-tagging).",
		["hs.settings.tagOnlyMode.label"] = "Tag only",
		["hs.settings.tagOnlyMode.info"] = "Disables damage between seekers/hiders. Catching is via tagging only.",
		["hs.settings.allowHidersKillSeekers.label"] = "Hiders can kill seekers",
		["hs.settings.allowHidersKillSeekers.info"] = "If enabled, hiders can eliminate seekers by damage. If disabled, damage from hiders is ignored (seekers can still die to environment/suicide).",
		["hs.settings.hiderAbilitiesEnabled.label"] = "Hider abilities",
		["hs.settings.hiderAbilitiesEnabled.info"] = "Enable hider abilities (dash/super jump).",
		["hs.settings.healthRegenEnabled.label"] = "Health regeneration",
		["hs.settings.healthRegenEnabled.info"] = "Enable health regeneration for active players.",
		["hs.settings.hiderTrailEnabled.label"] = "Hider trail",
		["hs.settings.hiderTrailEnabled.info"] = "Show a short-lived trail from moving hiders (helps seekers track).",
		["hs.settings.seekerMapEnabled.label"] = "Seeker map",
		["hs.settings.seekerMapEnabled.info"] = "Allow seekers to open the map.",

		["hs.ui.blind.title"] = "Seekers: WAIT",
		["hs.ui.blind.subtitle"] = "Hiders are hiding. Time left: {time}",

		["hs.ui.spectating.title"] = "Spectating",
		["hs.ui.spectating.subtitle"] = "Wait for the next round.",
		["hs.ui.spectating.following"] = "Spectating {name}",
		["hs.ui.spectating.noTeammate"] = "No active teammate to spectate.",

		["hs.banner.victory"] = "{winner} won!",

		["hs.ui.label.round"] = "Round",
		["hs.ui.label.phase"] = "Phase",
		["hs.ui.label.team"] = "Team",
		["hs.ui.label.seekers"] = "Seekers",
		["hs.ui.label.hiders"] = "Hiders",
		["hs.ui.label.status"] = "Status",

		["hs.ui.top.winsPrefix"] = "Wins: ",
		["hs.ui.top.rounds"] = "Rounds",
	},
	ru = {
		["hs.title"] = "Прятки",

		["hs.common.on"] = "Вкл",
		["hs.common.off"] = "Выкл",
		["hs.common.infinite"] = "Бесконечно",

		["hs.phase.setup"] = "Настройка",
		["hs.phase.hiding"] = "Прятки",
		["hs.phase.seeking"] = "Поиск",
		["hs.phase.intermission"] = "Перерыв",

		["hs.role.seeker"] = "ИСКАТЕЛЬ",
		["hs.role.hider"] = "ПРЯЧУЩИЙСЯ",
		["hs.role.spectator"] = "НАБЛЮДАТЕЛЬ",

		["hs.team.seekers"] = "Искатели",
		["hs.team.hiders"] = "Прячущиеся",

		["hs.status.playing"] = "Играет",
		["hs.status.spectating"] = "Наблюдение",

		["hs.toast.welcome"] = "Добро пожаловать. Выберите команду.",
		["hs.toast.lateJoin"] = "Матч уже идёт. Вы присоединитесь в следующем раунде.",
		["hs.toast.needPlayersPerTeam"] = "Нужно минимум 2 игрока (по одному в каждой команде).",
		["hs.toast.notEnoughPlayers"] = "Недостаточно игроков для продолжения.",
		["hs.toast.hideStarted"] = "Фаза пряток началась!",
		["hs.toast.seekStarted"] = "Фаза поиска началась!",
		["hs.toast.roundOver"] = "Раунд завершён.",
		["hs.toast.matchComplete"] = "Матч завершён. Возврат в настройку.",

		["hs.toast.taggingOffEliminate"] = "Отмечание отключено. Устраняйте прячущихся, чтобы поймать.",
		["hs.toast.noHiderInRange"] = "Нет прячущегося в радиусе.",

		["hs.ui.pickRole.tagPrompt"] = "Нажмите E, чтобы поймать",
		["hs.ui.pickRole.eliminatePrompt"] = "Устраните, чтобы поймать",
		["hs.ui.action.tag"] = "Поймать",

		["hs.ui.hostMenu.title"] = "Меню хоста",
		["hs.ui.hostMenu.settings"] = "Настройки режима",
		["hs.ui.hostMenu.start"] = "Старт",

		["hs.ui.adminMenu.title"] = "Админ-меню",
		["hs.ui.adminMenu.pauseButton"] = "HS Админ",
		["hs.ui.adminMenu.close"] = "Закрыть",
		["hs.ui.adminMenu.enforcement"] = "Ограничение оружия",
		["hs.ui.adminMenu.refreshTools"] = "Обновить инструменты",
		["hs.ui.adminMenu.disableAll"] = "Отключить все",
		["hs.ui.adminMenu.seekersOnly"] = "Только искатели",
		["hs.ui.adminMenu.hidersOnly"] = "Только прячущиеся",
		["hs.ui.adminMenu.both"] = "Обе команды",
		["hs.ui.adminMenu.weaponsTitle"] = "Инструменты и оружие",
		["hs.ui.loadout.both"] = "Обе команды",

		["hs.ui.settings.title"] = "НАСТРОЙКИ РЕЖИМА",
		["hs.ui.settings.resetDefaults"] = "Сбросить",
		["hs.ui.settings.close"] = "Закрыть",

		["hs.ui.teams.title"] = "Выберите команду",
		["hs.ui.teams.starting"] = "Запуск...",
		["hs.ui.teams.lockingIn"] = "Фиксация команд через",
		["hs.ui.teams.autoAssigningIn"] = "Автораспределение через",
		["hs.ui.teams.join"] = "Вступить",
		["hs.ui.teams.leave"] = "Выйти",

		["hs.settings.group.round"] = "Раунд",
		["hs.settings.group.rules"] = "Правила",
		["hs.settings.group.teams"] = "Команды",
		["hs.settings.group.tagging"] = "Метка",
		["hs.settings.group.gameplay"] = "Геймплей",

		["hs.settings.hideSeconds.label"] = "Время пряток",
		["hs.settings.hideSeconds.info"] = "Сколько времени искатели заблокированы/ослеплены в начале раунда.",
		["hs.settings.seekSeconds.label"] = "Время поиска",
		["hs.settings.seekSeconds.info"] = "Лимит времени для искателей, чтобы найти всех.",
		["hs.settings.intermissionSeconds.label"] = "Перерыв",
		["hs.settings.intermissionSeconds.info"] = "Пауза между раундами.",
		["hs.settings.roundsToPlay.label"] = "Раунды",
		["hs.settings.roundsToPlay.info"] = "Количество раундов (0 = бесконечно).",

		["hs.settings.infectionMode.label"] = "Режим заражения",
		["hs.settings.infectionMode.info"] = "Пойманные прячущиеся становятся искателями (вместо выбывания).",
		["hs.settings.swapTeamsEachRound.label"] = "Менять роли каждый раунд",
		["hs.settings.swapTeamsEachRound.info"] = "Менять искателей и прячущихся между раундами.",
		["hs.settings.maxTeamDiff.label"] = "Макс. разница команд",
		["hs.settings.maxTeamDiff.info"] = "Ограничить перекос команд (0 = строго поровну).",
		["hs.settings.seekerGraceSeconds.label"] = "Неуязвимость искателей",
		["hs.settings.seekerGraceSeconds.info"] = "Неуязвимость искателей после начала поиска (защищает от мгновенных ловушек, когда прячущиеся могут убивать).",
		["hs.settings.tagRangeMeters.label"] = "Дистанция метки",
		["hs.settings.tagRangeMeters.info"] = "Максимальная дистанция для метки искателем.",
		["hs.settings.taggingEnabled.label"] = "Метка",
		["hs.settings.taggingEnabled.info"] = "Если выключено, искатели должны устранять прячущихся уроном (без метки на E).",
		["hs.settings.tagOnlyMode.label"] = "Только метка",
		["hs.settings.tagOnlyMode.info"] = "Отключает урон между искателями/прячущимися. Поймать можно только меткой.",
		["hs.settings.allowHidersKillSeekers.label"] = "Прячущиеся могут убивать искателей",
		["hs.settings.allowHidersKillSeekers.info"] = "Если включено, прячущиеся могут устранять искателей уроном. Если выключено, урон от прячущихся игнорируется (искатели всё ещё могут погибнуть от окружения/самоподрыва).",
		["hs.settings.hiderAbilitiesEnabled.label"] = "Способности прячущихся",
		["hs.settings.hiderAbilitiesEnabled.info"] = "Включить способности прячущихся (рывок/суперпрыжок).",
		["hs.settings.healthRegenEnabled.label"] = "Регенерация здоровья",
		["hs.settings.healthRegenEnabled.info"] = "Включить регенерацию здоровья для активных игроков.",
		["hs.settings.hiderTrailEnabled.label"] = "След прячущихся",
		["hs.settings.hiderTrailEnabled.info"] = "Показывать кратковременный след за движущимися прячущимися (помогает искать).",
		["hs.settings.seekerMapEnabled.label"] = "Карта искателей",
		["hs.settings.seekerMapEnabled.info"] = "Разрешить искателям открывать карту.",

		["hs.ui.blind.title"] = "Искатели: ЖДИТЕ",
		["hs.ui.blind.subtitle"] = "Прячущиеся прячутся. Осталось: {time}",

		["hs.ui.spectating.title"] = "Наблюдение",
		["hs.ui.spectating.subtitle"] = "Ждите следующего раунда.",
		["hs.ui.spectating.following"] = "Наблюдение: {name}",
		["hs.ui.spectating.noTeammate"] = "Нет активного напарника для наблюдения.",

		["hs.banner.victory"] = "{winner} победили!",

		["hs.ui.label.round"] = "Раунд",
		["hs.ui.label.phase"] = "Фаза",
		["hs.ui.label.team"] = "Команда",
		["hs.ui.label.seekers"] = "Искатели",
		["hs.ui.label.hiders"] = "Прячущиеся",
		["hs.ui.label.status"] = "Статус",

		["hs.ui.top.winsPrefix"] = "Победы: ",
		["hs.ui.top.rounds"] = "Раунды",
	},
}

local function detectLanguage()
	if I.language and I.language ~= "" then
		return I.language
	end
	if type(I.detect) == "function" then
		local ok, v = pcall(I.detect)
		if ok and type(v) == "string" and v ~= "" then
			return v
		end
	end
	return I.defaultLanguage
end

local function formatParams(s, params)
	if type(s) ~= "string" then
		return tostring(s)
	end
	if type(params) ~= "table" then
		return s
	end
	return (string.gsub(s, "{(.-)}", function(key)
		local v = params[key]
		if v == nil then return "{" .. key .. "}" end
		return tostring(v)
	end))
end

function I.setLanguage(lang)
	if lang == nil or lang == "" then
		I.language = nil
		return
	end
	I.language = tostring(lang)
end

function I.t(key, params)
	local lang = detectLanguage()
	local dict = I.strings[lang] or I.strings[I.defaultLanguage] or {}
	local base = dict[key] or (I.strings[I.defaultLanguage] and I.strings[I.defaultLanguage][key]) or key
	return formatParams(base, params)
end

HS.t = HS.t or function(key, params)
	return I.t(key, params)
end
