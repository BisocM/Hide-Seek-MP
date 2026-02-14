--- UI Helper & Utility Functions

HS = HS or {}
HS.ui = HS.ui or {}
#include "../../../shared/theme.lua"
if HS.ui and HS.ui.theme and HS.ui.theme.applyGlobals then
	HS.ui.theme.applyGlobals()
end


--- Measure how much of a text string fits within given constraints (client).
function uiTextConstrained(text, font, fontSize, maxWidth, maxLines)
	UiPush()
	UiFont(font, fontSize)
	if maxLines and maxLines > 1 then
		UiWordWrap(maxWidth)
	end

	local function Fits(str)
		local sizeX, sizeY, posX, posY = UiGetTextSize(str)
		if maxLines and maxLines > 1 then
			local estimatedLineCount = math.max(1, math.floor(sizeY / fontSize + 0.5 ))
			return estimatedLineCount <= maxLines
		else
			return sizeX <= maxWidth
		end
	end

	local fits = Fits(text)
	local displayedText = text

	if not fits then
		local symbolCount = UiGetSymbolsCount(text)
		local lo = 1
		local hi = symbolCount
		local lastFits = lo
		while lo <= hi do
			local mid = math.floor((lo + hi) / 2)
			local testText = UiTextSymbolsSub(text, 1, mid).."…"
			if Fits(testText) then
				lo = mid + 1
				lastFits = mid
			else
				hi = mid - 1
			end
		end
		displayedText = UiTextSymbolsSub(text, 1, lastFits).."…"
	end
	UiPop()
	return fits, displayedText
end

--- Draw constrained text with error highlighting for overflow debugging (client).
function uiDrawTextConstrained(text, font, fontSize, maxWidth, maxLines)

	local fits, displayedText = uiTextConstrained(text, font, fontSize, maxWidth, maxLines)
	
	UiPush()
	UiFont(font, fontSize)
	if maxLines and maxLines > 1 then
		UiWordWrap(maxWidth)
	end
	if fits then
		UiText(displayedText)
	else
		UiColor(1,0,0,1)
		UiText(displayedText)
	end
	UiPop()
end

--- Draw constrained text that always uses ellipsis when truncated (client).
function uiDrawTextEllipsis(text, font, fontSize, maxWidth, maxLines)

	local fits, displayedText = uiTextConstrained(text, font, fontSize, maxWidth, maxLines)
	
	UiPush()
	UiFont(font, fontSize)
	if maxLines and maxLines > 1 then
		UiWordWrap(maxWidth)
	end
	UiText(displayedText)
	UiPop()
end

--- Retrieve the preview image path for a player's character (client).
function uiGetPlayerImage(playerId)
    local characterId = GetPlayerCharacter(playerId)
    local imagePath = GetString("characters."..characterId..".preview")
    if imagePath == "" or not UiHasImage(imagePath) then
        imagePath = "level/menu/script/avatarui/resources/preview_default.png"
    end
    return imagePath
end

--- Draw a player's preview image with optional rounded outline (client).
function uiDrawPlayerImage(playerId, width, height, roundingRadius, outlineColor, outlineThickness)

	local imagePath = uiGetPlayerImage(playerId)
			
	UiPush()
	UiColor(COLOR_WHITE)
	UiFillImage(imagePath)
	UiRoundedRect(width, height, roundingRadius)
	UiPop()
			
	if outlineColor and outlineThickness then
		UiPush()
		UiColor(unpack(outlineColor))
		UiRoundedRectOutline(width, height, roundingRadius, outlineThickness)
		UiPop()
	end
end

--- Draw a full player row including avatar and player name (client).
function uiDrawPlayerRow(playerId, height, maxWidth, color, dim)

	local r = 0.52
	local g = 0.52
	local b = 0.52

	if color then
		r = color[1]
		g = color[2]
		b = color[3]
	else
		local isUsed, pr, pg, pb = GetPlayerColor(playerId)
		if isUsed then
			r = pr
			g = pg
			b = pb
		end
	end

	local size = 32.0
	local scale = 1.0
	if height then
		scale = height/size
		size = height
	end

	local roundingRadius = 4 * scale
	local outlineThickness = 2 * scale

	UiPush()
	UiAlign("left top")

	uiDrawPlayerImage(playerId, size, size, roundingRadius, {r,g,b}, outlineThickness)

	UiPush()
	UiTranslate(size + 10 * scale, 0)
	
	if IsPlayerLocal(playerId) then
		UiColor(COLOR_YELLOW)
	elseif dim then
		UiColor(0.67, 0.67, 0.67)
	else
		UiColor(COLOR_WHITE)
	end

	UiPush()
	UiAlign("left bottom")
	local playerName = (HS.engine and HS.engine.playerName and HS.engine.playerName(playerId)) or GetPlayerName(playerId)
	local fits, displayedText = uiTextConstrained(playerName, FONT_BOLD, FONT_SIZE_20 * scale, maxWidth - (size + 10 * scale))
	local w,h,x,y = UiGetTextSize(displayedText)
	UiTranslate(0, size + y - (8 * scale))
	UiFont(FONT_BOLD, FONT_SIZE_20*scale)
	UiText(displayedText)
	UiPop()
	UiPop()

	UiPop()
end

--- Draw a styled primary action button (client).
function uiDrawPrimaryButton(title, width, disabled)
	return uiDrawButton(title, width, {0.5608, 0.8745, 0.6588, 0.4}, COLOR_YELLOW, true, disabled)
end


--- Draw a styled secondary action button (client).
function uiDrawSecondaryButton(title, width, disabled)
	return uiDrawButton(title, width, {0,0,0,0.2}, COLOR_YELLOW, true, disabled)
end

--- Draw a generic button with configurable background, hover colors and outline (client).
function uiDrawButton(title, width, color, hoverColor, outline, disabled)
	local pressed = false

	local alphaScale = 1
	if disabled then
		alphaScale = 0.2
	end

	UiPush()
		if color then
			UiColor(color[1], color[2], color[3], color[4] * alphaScale)
			UiRoundedRect(width, 40, 6)
		end

		UiButtonHoverColor(unpack(hoverColor))

		if outline then
			UiButtonImageBox("ui/common/box-outline-fill-6.png", 6, 6, 1, 1, 1, 1 * alphaScale)
		end
		
		UiFont(FONT_MEDIUM, FONT_SIZE_22)
		UiColor(1,1,1,1 * alphaScale)

		if disabled then
			UiDisableInput()
		end
		if UiTextButton(title, width, 40) then
			pressed = true
		end

	UiPop()

	return pressed
end

--- Draw a translucent panel with optional rounded corners (client).
function uiDrawPanel(width, height, radius)

	local hasRadius = radius and radius > 0

	UiPush()
		UiColor(COLOR_WHITE)
		UiBackgroundBlur(0.75)
		
		if hasRadius then
			UiRoundedRect(width, height, radius)
		else
			UiRect(width, height)
		end
	UiPop()
	
	UiPush()
		UiColor(COLOR_BLACK_TRNSP)
		
		if hasRadius then
			UiRoundedRect(width, height, radius)
		else
			UiRect(width, height)
		end
	UiPop()
end

--- Draw a text panel with background and padding (client).
function uiDrawTextPanel(message, alpha)


	local a = 1.0
	if alpha then
		a = alpha
	end

	UiPush()
	UiAlign("left top")

	UiFont(FONT_BOLD, FONT_SIZE_30)
	local w,h,x,y = UiGetTextSize(message)

	local panelWidth = w + 20
	local panelHeight = 42

	UiTranslate(-panelWidth/2,0)

	UiPush()
	UiColor(0,0,0,0.75 * a)
	UiRoundedRect(panelWidth, panelHeight, 8)
	UiPop()

	UiPush()
	
	UiTranslate(10, panelHeight - 10)
	UiColor(1,1,1,a)
	
	UiPush()
	UiAlign("left bottom")
	UiTranslate(0, y)
	UiText(message)
	UiPop()
	UiPop()

	UiPop()	
end


--- Draw a panel containing text and an image icon (client).
function uiDrawTextAndImagePanel(message, imageItem, alpha)
	UiPush()

		UiAlign("left top")

		local a = 1
		if alpha then
			a = alpha
		end

		local gap = 10
		local margin = 10

		UiFont(FONT_BOLD, FONT_SIZE_30)
		local w,h,x,y = UiGetTextSize(message)

		local imgSize = 24

		local panelHeight = 42
		local panelWidth = w + gap + imgSize + 2*margin

		UiTranslate(-panelWidth/2,0)

		UiPush()
		UiColor(0,0,0,0.75 * a)
		UiRoundedRect(panelWidth, panelHeight, 8)
		UiPop()

		UiPush()
		UiTranslate(10, panelHeight - 10)
		
		UiPush()
		UiColor(1,1,1,a)
		UiAlign("left bottom")
		UiTranslate(0, y)
		UiText(message)
		UiPop()

		UiPush()
		UiAlign("left bottom")
		UiTranslate(w + gap, 0)
		UiFillImage(imageItem.path)
		UiColor(imageItem.color[1], imageItem.color[2], imageItem.color[3], a)
		UiRoundedRect(imgSize, imgSize, 2)
		UiPop()

		UiPop()

	UiPop()	
end
