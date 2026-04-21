local Debris = game:GetService("Debris")

local HitContextTypes = require(script.Parent.Parent.HitContextTypes)

local M = {}

function M.Initialize(enabled)
	M.enabled = enabled
end

function M.EvaluateHit(context: HitContextTypes.HitContext)
	if not M.enabled then
		return { applies = false, valid = false }
	end

	local hitPart = context.hitPart
	if not hitPart.Anchored and not context.humanoid then
		return { applies = true, valid = true }
	end

	return { applies = false, valid = false }
end

function M.DealDamage(context: HitContextTypes.HitContext, _evaluation: HitContextTypes.HitEvaluation)
	local hitPart = context.hitPart
	local player = context.player
	local otherPlayer = context.otherPlayer
	local raycastResult = context.raycastResult
	local bulletCFrame = context.bulletCFrame
	local wepStats = context.wepStats

	local tempAtt = Instance.new("Attachment", hitPart)
	tempAtt.WorldCFrame = CFrame.new(raycastResult.Position) * (bulletCFrame - bulletCFrame.Position)
	local force = Instance.new("VectorForce", tempAtt)
	force.Attachment0 = tempAtt
	local buFo = wepStats.bulletForce
	force.Force = Vector3.new(0, 0, -buFo)
	Debris:AddItem(tempAtt, 0.1)
	if not otherPlayer then
		hitPart:SetNetworkOwner(player)
	end
	return nil
end

return M
