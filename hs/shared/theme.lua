
HS = HS or {}
HS.ui = HS.ui or {}
HS.ui.theme = HS.ui.theme or {}

local T = HS.ui.theme

T.fontScale = T.fontScale or 1.23

T.font = T.font or {
	bold = "bold.ttf",
	medium = "medium.ttf",
	regular = "regular.ttf",
	mono = "RobotoMono-Regular.ttf",
}

local fs = T.fontScale
T.fontSize = T.fontSize or {
	normal = {
		[80] = 80 * fs,
		[50] = 50 * fs,
		[40] = 40 * fs,
		[30] = 30 * fs,
		[25] = 25 * fs,
		[22] = 22 * fs,
		[20] = 20 * fs,
		[18] = 18 * fs,
	},
	special = {
		[36] = 36 * fs,
		[32] = 32 * fs,
	},
}

T.color = T.color or {
	black = { 0, 0, 0, 1 },
	blackTranslucent = { 0, 0, 0, 0.75 },
	white = { 1, 1, 1, 1 },
	yellow = { 1, 1, 0.5, 1 },
	red = { 0.9, 0.3, 0.3, 1 },

	textMuted = { 0.85, 0.85, 0.85, 1 },
	textSubtle = { 1, 1, 1, 0.65 },

	team1 = { 0.2, 0.55, 0.8, 1 },
	team2 = { 0.8, 0.25, 0.2, 1 },
	team3 = { 0.25, 0.25, 0.75, 1 },
	team4 = { 0.25, 0.75, 0.75, 1 },
}

T.radius = T.radius or {
	panel = 16,
	pill = 16,
}

T.alpha = T.alpha or {
	panelBlur = 0.75,
	glassBlur = 0.45,
	glassFill = 0.20,
	glassShade = 0.55,
	glassOutline = 0.08,
}

function T.applyGlobals()
	FONT_BOLD = T.font.bold
	FONT_MEDIUM = T.font.medium
	FONT_ROBOTO = T.font.mono

	FONT_SCALE = T.fontScale

	FONT_SIZE_80 = T.fontSize.normal[80]
	FONT_SIZE_50 = T.fontSize.normal[50]
	FONT_SIZE_40 = T.fontSize.normal[40]
	FONT_SIZE_30 = T.fontSize.normal[30]
	FONT_SIZE_25 = T.fontSize.normal[25]
	FONT_SIZE_22 = T.fontSize.normal[22]
	FONT_SIZE_20 = T.fontSize.normal[20]
	FONT_SIZE_18 = T.fontSize.normal[18]

	FONT_SIZE_36 = T.fontSize.special[36]
	FONT_SIZE_32 = T.fontSize.special[32]

	COLOR_BLACK = T.color.black
	COLOR_BLACK_TRNSP = T.color.blackTranslucent
	COLOR_WHITE = T.color.white
	COLOR_YELLOW = T.color.yellow
	COLOR_RED = T.color.red

	COLOR_TEAM_1 = T.color.team1
	COLOR_TEAM_2 = T.color.team2
	COLOR_TEAM_3 = T.color.team3
	COLOR_TEAM_4 = T.color.team4
end
