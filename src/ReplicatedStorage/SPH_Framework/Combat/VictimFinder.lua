--[[
	Handlers are organized into groups. Within each group, handlers run in order until one
	applies a valid hit (EvaluateHit returns applies+valid); that handler runs DealDamage and
	the rest of the group is skipped. The next group then runs the same way.

	Call Initialize once with dependencies (pass config from the server; handlers do not use GameAccess).
]]

local HitContextTypes = require(script.Parent.HitContextTypes)

local HitHandlers = script.Parent:WaitForChild("HitHandlers")
local DTSHandler = require(HitHandlers:WaitForChild("DTSHandler"))
local HumanHandler = require(HitHandlers:WaitForChild("HumanHandler"))
local GlassHandler = require(HitHandlers:WaitForChild("GlassHandler"))
local BulletImpulseHandler = require(HitHandlers:WaitForChild("BulletImpulseHandler"))

--- Each inner array is one “round”: at most one handler may run DealDamage per group.
local handlerGroups = {}

local M = {}

function M.Initialize(init)
	DTSHandler.Initialize(init.dts)
	HumanHandler.Initialize(init.human)
	GlassHandler.Initialize(init.glass)
	BulletImpulseHandler.Initialize(init.bulletImpulse.enabled)

	handlerGroups = {
		{ DTSHandler, HumanHandler, GlassHandler, BulletImpulseHandler },
	}
end

--- Returns false if a handler’s DealDamage requests an early stop for the rest of OnBulletHit.
function M.processDirectHit(context: HitContextTypes.HitContext)
	if #handlerGroups == 0 then
		warn("[VictimFinder] Initialize was not called; no hit handlers will run.")
		return true
	end

	for _, group in ipairs(handlerGroups) do
		for _, handler in ipairs(group) do
			local ev = handler.EvaluateHit(context)
			if ev.applies and ev.valid then
				local stopRestOfBulletHit = handler.DealDamage(context, ev)
				if stopRestOfBulletHit == false then
					return false
				end
				break
			end
		end
	end
	return true
end

return M
