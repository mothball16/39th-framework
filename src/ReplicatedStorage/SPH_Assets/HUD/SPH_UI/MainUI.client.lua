local players = game:GetService("Players")
local runService = game:GetService("RunService")
local assets = game:GetService("ReplicatedStorage").SPH_Assets
local player = players.LocalPlayer
local character = player.Character or player.CharacterAppearanceLoaded:Wait()
local tool, magAmmo, ammoPool
local ubglAmmo -- UBGL
local dead = false
local wepStats

local ammoUI = script.Parent.Ammo

script.Parent.Version.Text = "Spearhead "..require(assets.GameConfig).version

local ammoCounter = ammoUI.AmmoFrame.Frame.MagAmmo --ammoUI.MagAmmo
local ammoPoolUI = ammoUI.AmmoFrame.Frame.AmmoPool --ammoUI.AmmoPool
local bulletType = ammoUI.Other.AmmoType -- ammoUI.AmmoType
local fireMode = ammoUI.FiremodeFrame.Firemode --ammoUI.FireMode
local chambered = ammoUI.AmmoFrame.Frame.Chambered

-- DD_SPH Gunsmith: Icons for attachment status
local gunsmith = require(assets.Modules.Gunsmith)
local config = require(assets.GameConfig)
local attachmentFrame = ammoUI.AttachmentFrame
local newAttStats = {}

-- DD_SPH Modification: Text flashes to notify you of your aim sensitivity
local TweenService = game:GetService("TweenService")
local userInputService = game:GetService("UserInputService")
local tween   = TweenInfo.new(0.25, Enum.EasingStyle.Quart)
local aimSens = ammoUI.FiremodeFrame.Sens -- ammoUI.Firemode.Sens
-- </DD_SPH>

local fireModeNames = {"[SAFE]", "[SEMI]", "[AUTO]", "[BURST]", "[UBGL]", "[MANUAL]"}

--local fireModeNames = {"SAFE", "[S]", "[F]", "[B]", "[M]"}

-- Jarr's edited UI
function splitNumber(number) --thanks AI for doing the stuff im too lazy for
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
-- </Jarr's edited UI>

character.ChildAdded:Connect(function(newChild)
	if newChild:FindFirstChild("SPH_Weapon") and assets.WeaponModels:FindFirstChild(newChild.Name) and not dead then
		tool = newChild
		magAmmo = tool:WaitForChild("Ammo").MagAmmo
		ammoPool = tool.Ammo.ArcadeAmmoPool
		wepStats = require(tool.SPH_Weapon.WeaponStats)
		if wepStats.hasUBGL then -- UBGL
			ubglAmmo = tool:FindFirstChild("UBGLAmmo")
		else
			ubglAmmo = nil
		end -- </UBGL>
		if wepStats.Attachments then -- DD_SPH Gunsmith
			local model = character.WeaponRig.Weapon:WaitForChild(newChild.Name)
			newAttStats = gunsmith.getAttStats(wepStats.Attachments, model)
			if newAttStats and newAttStats.flashlights_server then
				attachmentFrame.Flashlight.Visible = true
			end
			if newAttStats and newAttStats.laserOrigin then
				attachmentFrame.Laser.Visible = true
			end
		end -- </DD_SPH>
		if assets.WeaponModels:FindFirstChild(newChild.Name).Grip:FindFirstChild("Flashlight") then
			attachmentFrame.Flashlight.Visible = true
		end
		if assets.WeaponModels:FindFirstChild(newChild.Name).Grip:FindFirstChild("Laser") then
			attachmentFrame.Laser.Visible = true
		end
		bulletType.Text = newAttStats.ammoType or wepStats.ammoType -- DD_SPH Gunsmith
	end
end)

character.ChildRemoved:Connect(function(oldChild)
	if oldChild == tool then
		tool = nil
		ubglAmmo = nil -- UBGL
		attachmentFrame.Laser.Visible = false -- DD_SPH Laser icon
		attachmentFrame.Flashlight.Visible = false -- DD_SPH Flashlight icon
		newAttStats = {}
	end
end)

runService.Heartbeat:Connect(function()
	if tool and (tool:FindFirstChild("Chambered") or wepStats.openBolt) and magAmmo and not dead then
		if character.Humanoid.SeatPart ~= nil and character.Humanoid.SeatPart.ClassName == "VehicleSeat" then return end -- DD_SPH: UI automatically hides while driving a vehicle
		ammoUI.Visible = true
		if not wepStats.operationType or type(wepStats.operationType) == "string" then wepStats.operationType = 1 end
		if tool.FireMode.Value == 4 and wepStats.hasUBGL and ubglAmmo then -- UBGL
			local ubglAmmoPool = tool:FindFirstChild("UBGLAmmoPool")
			ammoCounter.Text = ubglAmmo.Value
			ammoPoolUI.Text = "/" .. (ubglAmmoPool and ubglAmmoPool.Value or 0)
			bulletType.Text = wepStats.ubgl.ammoType
			chambered.TextTransparency = 1
			ammoCounter.TextColor3 = Color3.new(1,1,1)
			if ubglAmmo.Value > 0 then
				ammoCounter.TextColor3 = Color3.new(1,1,1)
			else
				ammoCounter.TextColor3 = Color3.new(1,0.1,0.1)
			end
		else -- </UBGL>
			if wepStats.operationType == 4 and tool.Chambered.Value then
				local digits = splitNumber(magAmmo.Value+1)
				ammoCounter.Text = [[<font transparency="0.5">]]..digits[1]..[[</font>]]..digits[2]
			else
				local digits = splitNumber(magAmmo.Value)
				ammoCounter.Text = [[<font transparency="0.5">]]..digits[1]..[[</font>]]..digits[2]
			end
			ammoPoolUI.Text = "/"
			if wepStats.infiniteAmmo then
				ammoPoolUI.Text = ammoPoolUI.Text.."INF"
			else
				--ammoPoolUI.Text = ammoPoolUI.Text..ammoPool.Value
				local digits = splitNumber(ammoPool.Value)
				ammoPoolUI.Text = ammoPoolUI.Text..[[<font transparency="0.5">]]..digits[1]..[[</font>]]..digits[2]
				if ammoPool.Value > 0 then
					ammoPoolUI.TextColor3 = Color3.fromRGB(255, 255, 255)
				else
					ammoPoolUI.TextColor3 = Color3.new(1,0,0)				
				end
			end
			if tool.FireMode.Value == 0 then
				ammoCounter.TextColor3 = Color3.new(0.5,0.5,0.5)
			elseif (tool:FindFirstChild("Chambered") and tool.Chambered.Value) or (wepStats.openBolt and magAmmo.Value > 1) then
				if wepStats.operationType < 4 then
					chambered.TextTransparency = 0
				end
				ammoCounter.TextColor3 = Color3.fromRGB(255,255,255)
			else
				chambered.TextTransparency = 1
				ammoCounter.TextColor3 = Color3.new(1, 0, 0)
			end
		end

		fireMode.Text = fireModeNames[tool.FireMode.Value + 1]
		aimSens.Text = string.format("%.2f", userInputService.MouseDeltaSensitivity)
	else
		ammoUI.Visible = false
	end
end)

character.Humanoid.Died:Connect(function()
	dead = true
end)

-- DD_SPH: Attachment Statuses
attachmentFrame.Flashlight.KeybindText.Text = "["..game:GetService("UserInputService"):GetStringForKeyCode(config.toggleFlashlight[1]).."]"
attachmentFrame.Laser.KeybindText.Text = "["..game:GetService("UserInputService"):GetStringForKeyCode(config.toggleLaser[1]).."]"

local userInputService = game:GetService("UserInputService")
local playerOnMobile = userInputService.TouchEnabled
if playerOnMobile then
	ammoUI.Position = UDim2.new(1, -30, 1, -100)
end