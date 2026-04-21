local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local HitContextTypes = require(script.Parent.Parent.HitContextTypes)

local M = {}

local _glassShatter = false
local _glassRespawnTime = 5
local _glassBreakSounds = {}

function M.Initialize(init)
	_glassShatter = init.glassShatter
	_glassRespawnTime = init.glassRespawnTime
	_glassBreakSounds = init.glassBreakSounds
end

function M.EvaluateHit(context: HitContextTypes.HitContext)
	if not _glassShatter then
		return { applies = false, valid = false }
	end

	local hitPart = context.hitPart
	if not (hitPart.Name == "Glass" or CollectionService:HasTag(hitPart, "BreakableGlass")) then
		return { applies = false, valid = false }
	end

	return { applies = true, valid = true }
end

function M.DealDamage(context: HitContextTypes.HitContext, _evaluation: HitContextTypes.HitEvaluation)
	local hitPart = context.hitPart
	local raycastResult = context.raycastResult
	local hitPosition = raycastResult.Position

	local prevTransparency = hitPart.Transparency
	local prevCanCollide = hitPart.CanCollide
	local prevCanQuery = hitPart.CanQuery
	local prevCanTouch = hitPart.CanTouch

	hitPart.Transparency = 1
	hitPart.CanCollide = false
	hitPart.CanQuery = false
	hitPart.CanTouch = false

	task.delay(_glassRespawnTime, function()
		if hitPart and hitPart.Parent then
			hitPart.Transparency = prevTransparency
			hitPart.CanCollide = prevCanCollide
			hitPart.CanQuery = prevCanQuery
			hitPart.CanTouch = prevCanTouch
		end
	end)

	local soundCount = #_glassBreakSounds
	if soundCount > 0 then
		local soundAtt = Instance.new("Attachment", workspace.Terrain)
		soundAtt.WorldPosition = hitPosition

		local shatterSound = _glassBreakSounds[math.random(soundCount)]:Clone()
		shatterSound.Parent = soundAtt
		shatterSound:Play()
		Debris:AddItem(soundAtt, shatterSound.TimeLength)
	end

	return nil
end

return M
