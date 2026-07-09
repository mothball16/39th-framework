local replicatedStorage = game:GetService("ReplicatedStorage")
local Framework = replicatedStorage.Systems.Weapon
local Access = require(Framework.Access)
local config = Access.Config
local dead = false

if config.fallDamage then
	local runService = game:GetService("RunService")
	local character = script:FindFirstAncestorWhichIsA("Model") :: Model
	local humanoid: Humanoid = character:WaitForChild("Humanoid")
	local humanoidRootPart: BasePart = character:WaitForChild("HumanoidRootPart")
	local prevHeight = humanoidRootPart.Position.Y

	local NetworkEvents = require(Framework.Network.NetworkEvents)
	local P = NetworkEvents.packets
	local fallDamageActive = true

	humanoid.Died:Connect(function()
		fallDamageActive = false
		dead = true
	end)

	local rayParams = RaycastParams.new()
	rayParams.IgnoreWater = false
	rayParams.RespectCanCollide = false
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { character }

	local distance = -3.1
	local fallingDist = 0
	local airborne = false
	-- ponytail: Heartbeat — fall tracking is gameplay state, not pre-render visuals
	runService.Heartbeat:Connect(function()
		if dead then
			return
		end
		if humanoid.Sit then
			fallingDist = 0
		end
		local rayResult = workspace:Raycast(humanoidRootPart.Position, Vector3.new(0, distance, 0), rayParams)
		if rayResult and rayResult.Instance and not script:GetAttribute("Override") then
			if airborne then
				airborne = false
				if fallingDist > config.fallDamageDist then
					local damage = (fallingDist - config.fallDamageDist) * config.fallDamageMultiplier
					if fallDamageActive then
						P.FallDamage.send({ damage = damage })
					end
				end
				fallingDist = 0
			end
		else
			airborne = true
		end

		local curHeight = humanoidRootPart.Position.Y
		if curHeight < prevHeight and airborne then
			fallingDist += prevHeight - curHeight
		else
			fallingDist = 0
		end
		prevHeight = curHeight
	end)

	humanoid.Climbing:Connect(function()
		fallingDist = 0
	end)

	humanoid.Swimming:Connect(function()
		fallingDist = 0
	end)
end
