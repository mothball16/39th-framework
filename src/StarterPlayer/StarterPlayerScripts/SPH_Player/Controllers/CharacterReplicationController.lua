local ReplicatedStorage = game:GetService("ReplicatedStorage")
local assets = ReplicatedStorage:WaitForChild("SPH_Assets")
local modules = assets:WaitForChild("Modules")
local bridgeNet = require(modules.BridgeNet)

local repLean = bridgeNet.CreateBridge("ReplicateLean")

local CharacterReplicationController = {}

local targetNeckC1s = {}
local targetRootC1s = {}

function CharacterReplicationController.Initialize()


	repLean:Connect(function(character: Model, leanDirection: number)
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		local humanoid = character:FindFirstChild("Humanoid")
		if not rootPart or not humanoid then return end
		
		local targetCFrame
		local baseJoint

		if humanoid.RigType == Enum.HumanoidRigType.R6 then
			baseJoint = rootPart:FindFirstChild("RootJoint")
			if baseJoint then
				targetCFrame = CFrame.new(-leanDirection / 2, 0, 0) * CFrame.Angles(math.rad(90), math.rad(180) + math.rad(17 * leanDirection), 0)
			end
		else
			local upperTorso = character:FindFirstChild("UpperTorso")
			baseJoint = upperTorso and upperTorso:FindFirstChild("Waist")
			if baseJoint then
				targetCFrame = CFrame.new(baseJoint.C1.Position.X, baseJoint.C1.Position.Y, baseJoint.C1.Position.Z) * CFrame.Angles(0, 0, math.rad(17 * leanDirection))
			end
		end

		if baseJoint and targetCFrame then
			targetRootC1s[baseJoint] = targetCFrame
		end
	end)
end

function CharacterReplicationController.UpdateRender(dt)
	local headLerpAlpha = 1 - math.exp(-12 * dt)
	for joint, targetC1 in pairs(targetNeckC1s) do
		if joint.Parent then
			joint.C1 = joint.C1:Lerp(targetC1, headLerpAlpha)
		else
			-- Clean up cache automatically when a character is destroyed
			targetNeckC1s[joint] = nil
		end
	end
	
	local leanLerpAlpha = 1 - math.exp(-8 * dt)
	for joint, targetC1 in pairs(targetRootC1s) do
		if joint.Parent then
			joint.C1 = joint.C1:Lerp(targetC1, leanLerpAlpha)
		else
			-- Clean up cache automatically when a character is destroyed
			targetRootC1s[joint] = nil
		end
	end
end

return CharacterReplicationController