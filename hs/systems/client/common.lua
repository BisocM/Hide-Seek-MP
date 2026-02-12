HS = HS or {}
HS.systems = HS.systems or {}
HS.systems.client = HS.systems.client or {}
HS.systems.client.common = HS.systems.client.common or {}

local C = HS.systems.client.common

local function ensureCache(ctx)
	if type(ctx) ~= "table" then return nil end
	ctx.cache = ctx.cache or {}
	return ctx.cache
end

function C.sharedAndVm(ctx)
	local cache = ensureCache(ctx)
	if cache then
		local frame = tonumber(ctx.frame) or 0
		if cache._clientVmFrame == frame then
			return cache._clientVmShared, cache._clientVmValue
		end
	end

	local sh = HS.select and HS.select.shared and HS.select.shared() or nil
	local vm = nil
	if sh and HS.select and HS.select.matchVm then
		vm = HS.select.matchVm(ctx, sh)
	end

	if cache then
		cache._clientVmFrame = tonumber(ctx.frame) or 0
		cache._clientVmShared = sh
		cache._clientVmValue = vm
	end
	return sh, vm
end

function C.anyVm(ctx)
	local _sh, vm = C.sharedAndVm(ctx)
	return vm
end

function C.enforceSeekerMapSetting(vm)
	if not vm or not vm.ready then return end
	if not vm.settings or vm.settings.seekerMapEnabled == true then return end
	if not vm.me or vm.me.team ~= HS.const.TEAM_SEEKERS then return end

	SetBool("game.disablemap", true)
	if GetBool("game.map.enabled") then
		SetBool("game.map.enabled", false)
	end
end
