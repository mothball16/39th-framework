local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local DamageLogic = require(script.Parent.Parent.DamageLogic)
local HitContextTypes = require(script.Parent.Parent.HitContextTypes)

local M = {}

local _leaderboard = false
local _leaderboardTKStat = ""
local _leaderboardKillStat = ""

function M.Initialize(init)
	_leaderboard = init.leaderboard
	_leaderboardTKStat = init.leaderboardTKStat
	_leaderboardKillStat = init.leaderboardKillStat
end

function M.EvaluateHit(context: HitContextTypes.HitContext)
	local humanoid = context.humanoid
	if not humanoid or humanoid.Health <= 0 then
		return { applies = false, valid = false }
	end
	if not context.allowHumanDamage then
		return { applies = true, valid = false }
	end

	local ray = context.raycastResult
	local dist = (typeof(ray.Position) == "Vector3" and typeof(ray.Origin) == "Vector3")
			and (ray.Position - ray.Origin).Magnitude
		or nil
	local damage = DamageLogic.getDamage(context.wepStats.damage, context.hitPart.Name, dist, context.wepStats.range)

	return {
		applies = true,
		valid = true,
		damage = damage,
	}
end

function M.DealDamage(context: HitContextTypes.HitContext, evaluation: HitContextTypes.HitEvaluation)
	local humanoid = context.humanoid
	assert(humanoid, "Human DealDamage expects context.humanoid")
	local player = context.player
	local damage = evaluation.damage
	assert(damage ~= nil, "Human DealDamage expects evaluation.damage")

	if humanoid.Health > 0 and humanoid.Health - damage <= 0 then
		if _leaderboard and (player.Name ~= humanoid.Parent.Name) then
			local victimPlayer = Players:GetPlayerFromCharacter(humanoid.Parent)
			local leaderstats = player:FindFirstChild("leaderstats")
			if leaderstats and victimPlayer and victimPlayer.Team == player.Team then
				local tkStat = leaderstats:FindFirstChild(_leaderboardTKStat)
				if tkStat and tkStat:IsA("IntValue") then
					tkStat.Value += 1
				end
			elseif leaderstats and victimPlayer then
				local killStat = leaderstats:FindFirstChild(_leaderboardKillStat)
				if killStat and killStat:IsA("IntValue") then
					killStat.Value += 1
				end
			end
		end
		local killer = Instance.new("ObjectValue", humanoid.Parent)
		killer.Name = "Killer"
		killer.Value = player
	end

	local creator = Instance.new("ObjectValue")
	creator.Name = "creator"
	creator.Value = player
	creator.Parent = humanoid
	Debris:AddItem(creator, 0.5)

	humanoid:TakeDamage(damage)
	return nil
end

return M
