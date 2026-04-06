local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Charm = require(Packages.Charm)

local assets = ReplicatedStorage:WaitForChild("SPH_Assets")
local config = require(assets.GameConfig)

local State = require(script.Parent.CharacterState)
local WeaponState = require(script.Parent.WeaponState)

local UIController = {
	PlayerGui = nil,
	MainUI = nil,
	ammoUI = nil,
	
	ammoCounter = nil,
	ammoPoolUI = nil,
	bulletType = nil,
	fireMode = nil,
	chambered = nil,
	attachmentFrame = nil,
	aimSens = nil,
	
	fireModeNames = {"[SAFE]", "[SEMI]", "[AUTO]", "[BURST]", "[UBGL]", "[MANUAL]"},
	
	ubglAmmo = nil
}

function UIController.splitNumber(number)
	local numberStr = tostring(number)
	local leadingZeros = ""
	local restOfNumber = numberStr

	-- Calculate the number of leading zeros needed
	local totalLength = 3
	local leadingZerosCount = totalLength - #numberStr

	-- Add leading zeros if necessary
	if leadingZerosCount > 0 then
		for i = 1, leadingZerosCount do
			leadingZeros = leadingZeros .. "0"
		end
	end

	-- If the number is longer than 3 digits, take the last 3 digits only
	if #numberStr > totalLength then
		restOfNumber = numberStr:sub(-totalLength)
		leadingZeros = ""
	end

	return {leadingZeros, restOfNumber}
end

function UIController.Initialize(params)
	UIController.PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	UIController.MainUI = UIController.PlayerGui:WaitForChild("SPH_UI")
	
	UIController.ammoUI = UIController.MainUI:WaitForChild("Ammo")
	UIController.MainUI:WaitForChild("Version").Text = "Spearhead "..config.version
	
	UIController.ammoCounter = UIController.ammoUI.AmmoFrame.Frame.MagAmmo
	UIController.ammoPoolUI = UIController.ammoUI.AmmoFrame.Frame.AmmoPool
	UIController.bulletType = UIController.ammoUI.Other.AmmoType
	UIController.fireMode = UIController.ammoUI.FiremodeFrame.Firemode
	UIController.chambered = UIController.ammoUI.AmmoFrame.Frame.Chambered
	
	UIController.attachmentFrame = UIController.ammoUI:WaitForChild("AttachmentFrame")
	UIController.aimSens = UIController.ammoUI.FiremodeFrame.Sens

	UIController.attachmentFrame.Flashlight.KeybindText.Text = "["..UserInputService:GetStringForKeyCode(config.toggleFlashlight[1]).."]"
	UIController.attachmentFrame.Laser.KeybindText.Text = "["..UserInputService:GetStringForKeyCode(config.toggleLaser[1]).."]"

	if UserInputService.TouchEnabled then
		UIController.ammoUI.Position = UDim2.new(1, -30, 1, -100)
	end
	
	Charm.subscribe(State.equippedTool, UIController.OnEquippedToolChanged)
    Charm.subscribe(State.aiming, UIController.OnAimToggled)
end

function UIController.OnAimToggled(aiming)
    UIController.aimSens.TextTransparency = aiming and 0 or 1
end


function UIController.OnEquippedToolChanged(tool)
	if tool then
		if WeaponState.wepStats and WeaponState.wepStats.hasUBGL then
			UIController.ubglAmmo = tool:FindFirstChild("UBGLAmmo")
		else
			UIController.ubglAmmo = nil
		end
		
		if WeaponState.attStats and WeaponState.attStats.flashlights_server then
			UIController.attachmentFrame.Flashlight.Visible = true
		end
		if WeaponState.attStats and WeaponState.attStats.laserOrigin then
			UIController.attachmentFrame.Laser.Visible = true
		end
		
		local wepModel = assets.WeaponModels:FindFirstChild(tool.Name)
		if wepModel and wepModel.Grip:FindFirstChild("Flashlight") then
			UIController.attachmentFrame.Flashlight.Visible = true
		end
		if wepModel and wepModel.Grip:FindFirstChild("Laser") then
			UIController.attachmentFrame.Laser.Visible = true
		end
		
		if WeaponState.attStats and WeaponState.attStats.ammoType then
			UIController.bulletType.Text = WeaponState.attStats.ammoType
		elseif WeaponState.wepStats and WeaponState.wepStats.ammoType then
			UIController.bulletType.Text = WeaponState.wepStats.ammoType
		end
	else
		UIController.ubglAmmo = nil
		if UIController.attachmentFrame then
			UIController.attachmentFrame.Laser.Visible = false
			UIController.attachmentFrame.Flashlight.Visible = false
		end
	end
end

function UIController.UpdateHeartbeat(dt)
	local tool = State.equippedTool()
	local wepStats = WeaponState.wepStats
	local magAmmo = WeaponState.gunAmmo and WeaponState.gunAmmo:FindFirstChild("MagAmmo")
	
	if not UIController.ammoUI then return end

	if tool and wepStats and (tool:FindFirstChild("Chambered") or wepStats.openBolt) and magAmmo and not State.dead() then
		if State.Parts.Humanoid.SeatPart ~= nil and State.Parts.Humanoid.SeatPart.ClassName == "VehicleSeat" then return end
		UIController.ammoUI.Visible = true
		
		local fireModeVal = WeaponState.fireMode()
		
		if fireModeVal == 4 and wepStats.hasUBGL and UIController.ubglAmmo then
			local ubglAmmoPool = tool:FindFirstChild("UBGLAmmoPool")
			UIController.ammoCounter.Text = UIController.ubglAmmo.Value
			UIController.ammoPoolUI.Text = "/" .. (ubglAmmoPool and ubglAmmoPool.Value or 0)
			UIController.bulletType.Text = wepStats.ubgl.ammoType
			UIController.chambered.TextTransparency = 1
			UIController.ammoCounter.TextColor3 = Color3.new(1,1,1)
			if UIController.ubglAmmo.Value > 0 then
				UIController.ammoCounter.TextColor3 = Color3.new(1,1,1)
			else
				UIController.ammoCounter.TextColor3 = Color3.new(1,0.1,0.1)
			end
		else
			local chamberedVal = tool:FindFirstChild("Chambered") and tool.Chambered.Value
			
			if wepStats.operationType == 4 and chamberedVal then
				local digits = UIController.splitNumber(magAmmo.Value+1)
				UIController.ammoCounter.Text = [[<font transparency="0.5">]]..digits[1]..[[</font>]]..digits[2]
			else
				local digits = UIController.splitNumber(magAmmo.Value)
				UIController.ammoCounter.Text = [[<font transparency="0.5">]]..digits[1]..[[</font>]]..digits[2]
			end
			
			UIController.ammoPoolUI.Text = "/"
			if wepStats.infiniteAmmo then
				UIController.ammoPoolUI.Text = UIController.ammoPoolUI.Text.."INF"
			else
				local ammoPoolVal = WeaponState.gunAmmo.ArcadeAmmoPool.Value
				local digits = UIController.splitNumber(ammoPoolVal)
				UIController.ammoPoolUI.Text = UIController.ammoPoolUI.Text..[[<font transparency="0.5">]]..digits[1]..[[</font>]]..digits[2]
				if ammoPoolVal > 0 then
					UIController.ammoPoolUI.TextColor3 = Color3.fromRGB(255, 255, 255)
				else
					UIController.ammoPoolUI.TextColor3 = Color3.new(1,0,0)				
				end
			end
			
			if fireModeVal == 0 then
				UIController.ammoCounter.TextColor3 = Color3.new(0.5,0.5,0.5)
			elseif chamberedVal or (wepStats.openBolt and magAmmo.Value > 1) then
				if wepStats.operationType < 4 then
					UIController.chambered.TextTransparency = 0
				end
				UIController.ammoCounter.TextColor3 = Color3.fromRGB(255,255,255)
			else
				UIController.chambered.TextTransparency = 1
				UIController.ammoCounter.TextColor3 = Color3.new(1, 0, 0)
			end
		end

		UIController.fireMode.Text = UIController.fireModeNames[fireModeVal + 1]
		UIController.aimSens.Text = string.format("%.2f", WeaponState.aimSens())
	else
		UIController.ammoUI.Visible = false
	end
end

return UIController