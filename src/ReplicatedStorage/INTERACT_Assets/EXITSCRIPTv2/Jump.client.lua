local UIS = game:GetService("UserInputService")
local Plr = game:GetService("Players").LocalPlayer
local dts_install = game.ReplicatedStorage:FindFirstChild("DTS_Assets")
local cfg = dts_install and require(dts_install.GlobalSettings) 

local Used = false

local function ExitFunc(Input, Proccesed)
	if Proccesed or Used then return end

	if Input.KeyCode==Enum.KeyCode.Space or Input.KeyCode==Enum.KeyCode.ButtonA then
		if cfg and cfg.JumpPreventionSpeed~=nil and Plr.Character.HumanoidRootPart.AssemblyLinearVelocity.Magnitude >= cfg.JumpPreventionSpeed then return end
		
		Plr.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		Used = true
	end
end
connect = UIS.InputBegan:Connect(ExitFunc)