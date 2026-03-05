HS = HS or {}
HS.cli = HS.cli or {}
HS.cli.pregame = HS.cli.pregame or {}

function HS.cli.pregame.draw(dt, _ctx, _vm)
	local teamState = (shared and shared._teamState and shared._teamState.state) or _WAITING
	local showTeamSelect = teamState ~= _DONE
	local setupLocked = teamState >= (_COUNTDOWN or 2)

	if showTeamSelect then
		teamsDraw(dt)
	else
		UiPush()
		UiAlign("left top")
		UiColor(0, 0, 0, 0.90)
		UiRect(UiWidth(), UiHeight())
		UiPop()
	end

	if not hudGameIsSetup() and not setupLocked then
		local settings = (HS.settings and HS.settings.schema and HS.settings.schema()) or {}
		if hudDrawGameSetup(settings) then
			local payload = (HS.settings and HS.settings.readHostStartPayload and HS.settings.readHostStartPayload(HS.persist)) or {}
			local localId = (HS.engine and HS.engine.localPlayerId and HS.engine.localPlayerId()) or 0
			if HS.app and HS.app.commands and HS.app.commands.startMatch then
				HS.app.commands.startMatch(payload, localId)
			end
		end
	end
end
