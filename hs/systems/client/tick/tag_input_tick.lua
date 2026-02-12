HS = HS or {}
HS.systems = HS.systems or {}
HS.systems.client = HS.systems.client or {}

HS.systems.client.tagInputTick = HS.systems.client.tagInputTick or {
	name = "tag-input",
}

function HS.systems.client.tagInputTick.tick(_self, ctx, _dt)
	local sh, vm = HS.systems.client.common.sharedAndVm(ctx)
	if not sh or not vm or not vm.ready then return false end
	if vm.phase ~= HS.const.PHASE_SEEKING then return false end
	if not vm.settings or vm.settings.taggingEnabled ~= true then return false end
	if not vm.me or vm.me.team ~= HS.const.TEAM_SEEKERS or vm.me.out then return false end

	if HS.input and HS.input.pressed and HS.input.pressed("tag") then
		HS.engine.serverCall("server.hs_requestTag", vm.me.id)
	end
	return false
end
