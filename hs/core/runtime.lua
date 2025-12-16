
HS = HS or {}
HS.runtime = HS.runtime or {}

function HS.runtime.beginFrame(ctx, dt)
	if not ctx then return end
	ctx.frame = (ctx.frame or 0) + 1
	ctx.dt = tonumber(dt) or 0
	local engine = (ctx.engine or HS.engine)
	if engine and engine.now then
		ctx.now = tonumber(engine.now()) or 0
	else
		ctx.now = 0
	end
end

