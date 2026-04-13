-- Third-person weapon rig creation and shoulder / weld toggling.

local M = {}

M.bodyparts = { "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand" }

local ctx

local function enableMotors(char: Model)
	for i = 1, #M.bodyparts do
		local charArm = char:FindFirstChild(M.bodyparts[i])
		if charArm then
			for _, motor in pairs(charArm:GetChildren()) do
				if motor:IsA("Motor6D") then
					motor.Enabled = true
				end
			end
		end
	end
end

function M.MakeCharacterRig(char: Model)
	local head = char:WaitForChild("Head", 20)
	local humanoid = char:FindFirstChildWhichIsA("Humanoid")

	local rig = ctx.viewMod.RigModel(nil, true, head)
	rig.Parent = char

	if humanoid.RigType == Enum.HumanoidRigType.R6 then
		local lArmWeld = ctx.weldMod.BlankWeld(rig["Left Arm"], char["Left Arm"])
		lArmWeld.Parent = rig
		lArmWeld.Name = "law"
		rig["Left Arm"].Transparency = 1

		local rArmWeld = ctx.weldMod.BlankWeld(rig["Right Arm"], char["Right Arm"])
		rArmWeld.Parent = rig
		rArmWeld.Name = "raw"
		rig["Right Arm"].Transparency = 1
	else
		for i = 1, #M.bodyparts do
			local rigArm = rig[M.bodyparts[i]]
			local charArm = char[M.bodyparts[i]]
			local weld = ctx.weldMod.BlankWeld(rigArm, charArm)
			weld.Parent = rig
			weld.Name = M.bodyparts[i] .. "_w"
			rigArm.Transparency = 1
			weld.Enabled = false
		end

		enableMotors(char)
	end

	local animController = Instance.new("AnimationController", rig)
	Instance.new("Animator", animController)

	return rig
end

function M.ToggleRig(character: Model, toggle: boolean)
	for _, part in ipairs(character.WeaponRig:GetChildren()) do
		if part:IsA("Weld") then
			if not part.Part0 or not part.Part1 or not part.Part0.Parent or not part.Part1.Parent then
				print(part.Name .. " should be dead >:(")
				part.Part1 = character[part.Part0.Name]
			end
		end
	end
	task.wait()

	if character.Humanoid.RigType == Enum.HumanoidRigType.R6 then
		local torso = character.Torso
		local rig = character.WeaponRig
		torso["Left Shoulder"].Enabled = not toggle
		torso["Right Shoulder"].Enabled = not toggle
		rig.law.Enabled = toggle
		rig.raw.Enabled = toggle
	else
		character["LeftUpperArm"]["LeftShoulder"].Enabled = not toggle
		character["LeftLowerArm"]["LeftElbow"].Enabled = not toggle
		character["LeftHand"]["LeftWrist"].Enabled = not toggle
		character["RightUpperArm"]["RightShoulder"].Enabled = not toggle
		character["RightLowerArm"]["RightElbow"].Enabled = not toggle
		character["RightHand"]["RightWrist"].Enabled = not toggle
		local rig = character.WeaponRig
		for i = 1, #M.bodyparts do
			rig[M.bodyparts[i] .. "_w"].Enabled = toggle
		end
	end
end

function M.Initialize(c)
	ctx = c
end

return M
