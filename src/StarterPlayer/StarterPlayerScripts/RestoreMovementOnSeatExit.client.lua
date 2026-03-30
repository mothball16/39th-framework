local player = game:GetService("Players").LocalPlayer

local function setup(character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid:GetPropertyChangedSignal("SeatPart"):Connect(function()
		if not humanoid.SeatPart then
			humanoid.JumpPower = 50
			humanoid.UseJumpPower = true
			humanoid.WalkSpeed = 16
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
		end
	end)
end

if player.Character then
	setup(player.Character)
end
player.CharacterAdded:Connect(setup)
