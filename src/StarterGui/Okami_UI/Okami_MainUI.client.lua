--// Okami_DD
--// MainUI Script
--// Modified by Jarr for Dragoon's Den

local RunService = game:GetService('RunService')
local Players = game:GetService('Players')
local GuiService = game:GetService('GuiService')
local UserInput = game:GetService("UserInputService")
local tweens = game:GetService("TweenService")

while not Players.LocalPlayer do
	task.wait()
end
local LocalPlayer = Players.LocalPlayer
local RobloxGui = script.Parent
local CurrentVehicleSeat = nil
local CurrentVehicle

local SpeedText = script.Parent.Drive.SpeedFrame.SpeedLabel
local SpeedUnit = script.Parent.Drive.SpeedFrame.SpeedUnit
local FuelText = script.Parent.Drive.FuelFrame.FuelLabel
local HPText = script.Parent.Drive.HPFrame.HPLabel

local mobileControls = script.Parent.MobileControl
local ControlText = script.Parent.Controls
local VehicleName = script.Parent.CarName

local VehicleSeatHeartbeatCn
local currentUnits = 1

local twInfo = TweenInfo.new(0.5,	Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false)
local twVicName = tweens:Create(VehicleName.Label, twInfo, {TextTransparency = 1})

local UNITS	= {								--Click on speed to change units
	--First unit is default	
	{
		units			= "MPH"				,
		scaling			= (10/12) * (60/88)	, -- 1 stud : 10 inches | ft/s to MPH
		maxSpeed		= 230				,
		spInc			= 20				, -- Increment between labelled notches
	},

	{
		units			= "KM/H"			,
		scaling			= (10/12) * 1.09728	, -- 1 stud : 10 inches | ft/s to KP/H
		maxSpeed		= 370				,
		spInc			= 40				, -- Increment between labelled notches
	},

	{
		units			= "SPS"				,
		scaling			= 1					, -- Roblox standard
		maxSpeed		= 400				,
		spInc			= 40				, -- Increment between labelled notches
	}
}

--[[ Local Functions ]]--
local function executeButton()
	if not CurrentVehicle then return end


end

local function switchUnit()
	if currentUnits==#UNITS then
		currentUnits = 1
	else
		currentUnits = currentUnits+1
	end
end

local function switchControls()
	if not UserInput.KeyboardEnabled or not CurrentVehicle then 
		ControlText.Controls.Visible = false
		return 
	end

	ControlText.Controls.Visible = not ControlText.Controls.Visible
	ControlText.Plop:Play()
end

local function FindModelWithCode(models:{Model}, targetCode)
	for _, model in models do
		local code = model:GetAttribute("Weapon_Code") or model:GetAttribute("Addon_Code")
		if code and targetCode==code then return model end
	end
end

local function setControls(vehicle, seat, driver)
	local controlString = ""
	local canDTS = false
	local canInd = false
	local canNV = false
	local canRange = false
	local canZero = false --we use these to avoid repeating instructions
	local canSmoke = false
	local canLaser = false
	local canRadar = false
	local canSpot = false
	local color1 = "#"..Color3.fromRGB(255, 130, 41):ToHex() --Titles
	local color2 = "#"..Color3.fromRGB(220, 155, 109):ToHex() --Keybinds
	local color3 = Color3.fromRGB(248, 248, 248) --Everything else
	
	if vehicle:HasTag("Okami_Chassis") and driver then
		controlString = controlString..
			[[<b><font color="]]..color1..[[">Vehicle Controls</font></b>]]..
			[[<br/><b><font color="]]..color2..[[">T</font></b> Engine]]..
			[[<br/><b><font color="]]..color2..[[">L</font></b> Lights]]..
			[[<br/><b><font color="]]..color2..[[">E/Q</font></b> Blinkers]].. 
			[[<br/><b><font color="]]..color2..[[">X</font></b> Hazards]].. 
			[[<br/><b><font color="]]..color2..[[">H</font></b> Horn]]..
			[[<br/><b><font color="]]..color2..[[">Alt+H</font></b> Radio]]
	end

	if vehicle:GetAttribute("Internal_Strobe") then
		controlString = controlString..
			[[<br/><b><font color="]]..color2..[[">Alt+F/V</font></b> Strobe Lights]]..
			[[<br/><b><font color="]]..color2..[[">Alt+G</font></b> Siren]]
		local buttonFind1 = mobileControls.UIListLayout:FindFirstChild("Siren")
		if buttonFind1 then buttonFind1.Parent = mobileControls end

		local buttonFind2 = mobileControls.UIListLayout:FindFirstChild("Strobes")
		if buttonFind2 then buttonFind2.Parent = mobileControls end
	else
		local buttonFind1 = mobileControls:FindFirstChild("Siren")
		if buttonFind1 then buttonFind1.Parent = mobileControls.UIListLayout end

		local buttonFind2 = mobileControls:FindFirstChild("Strobes")
		if buttonFind2 then buttonFind2.Parent = mobileControls.UIListLayout end
	end

	if vehicle:GetAttribute("Car_CanTow") then
		controlString = controlString..
			[[<br/><b><font color="]]..color2..[[">C</font></b> Towing Hitch]]

		local buttonFind1 = mobileControls.UIListLayout:FindFirstChild("Hitch")
		if buttonFind1 then buttonFind1.Parent = mobileControls end
	else
		local buttonFind1 = mobileControls:FindFirstChild("Hitch")
		if buttonFind1 then buttonFind1.Parent = mobileControls.UIListLayout end
	end
	
	for each, tag in seat:GetChildren() do
		if tag.Name == "ControlsSystem" then 
			local weaponObj = FindModelWithCode(vehicle.Weapons:GetChildren(), tag.Value)
			if not weaponObj then continue end

			local weaponCfg = require(weaponObj:FindFirstChildWhichIsA("ModuleScript"))
			if not weaponCfg then continue end

			if not canDTS then
				canDTS = true
				controlString = controlString..
					[[<br/><br/><b><font color="]]..color1..[[">Dragoon Tank System</font></b>]]..
					[[<br/><b><font color="]]..color2..[[">F</font></b> Switch Weapon]]..
					[[<br/><b><font color="]]..color2..[[">V</font></b> Switch Firemode]]..
					[[<br/><b><font color="]]..color2..[[">G</font></b> Gunsights]].. 
					[[<br/><b><font color="]]..color2..[[">R</font></b> Reload]].. 
					[[<br/><b><font color="]]..color2..[[">RMB+Scroll Wheel</font></b> Zoom]].. 
					[[<br/><b><font color="]]..color2..[[">Scroll Wheel</font></b> Aim Sens]]
			end
			if not canZero and weaponCfg.CanZero then
				canZero = true
				controlString = controlString..
					[[<br/><b><font color="]]..color2..[[">[</font></b> Decrease/Reset Zero]]..
					[[<br/><b><font color="]]..color2..[[">]</font></b> Increase/Set Zero]]
			end		
			if not canRange and weaponCfg.RangefinderAllowed then
				canRange = true
				controlString = controlString..
					[[<br/><b><font color="]]..color2..[[">B</font></b> Rangefinder]]
			end
			if not canNV and (weaponCfg.GunnerScopeNightVis or weaponCfg.GunnerScopeInfrared) then
				canNV = true
				controlString = controlString..
					[[<br/><b><font color="]]..color2..[[">N</font></b> Nightvision/Infrared]]
			end
			if not canInd and weaponCfg.IndirectSwitch then
				canInd = true
				controlString = controlString..
					[[<br/><b><font color="]]..color2..[[">M</font></b> Indirect Fire Switch]]
			end
			
		elseif tag.Name == "ControlsModule" then 
			local weaponObj = FindModelWithCode(vehicle.Addons:GetChildren(), tag.Value)
			if not weaponObj then continue end

			local weaponCfg = require(weaponObj:FindFirstChildWhichIsA("ModuleScript"))
			if not weaponCfg then continue end

			if not canSmoke and weaponCfg.CounterKeybind then
				canSmoke = true
				controlString = controlString..
					[[<br/><b><font color="]]..color2..[[">]]..weaponCfg.CounterKeybind.Name..[[</font></b> Countermeasures]]
			end
			if not canRadar and weaponCfg.RadarUnlockKeybind then
				canRadar = true
				controlString = controlString..
					[[<br/><b><font color="]]..color2..[[">]]..weaponCfg.RadarUnlockKeybind.Name..[[</font></b> Clear Radar Target]]
			end
			if not canLaser and weaponCfg.LaserKeybind then
				canLaser = true
				controlString = controlString..
					[[<br/><b><font color="]]..color2..[[">]]..weaponCfg.LaserKeybind.Name..[[</font></b> Set/Toggle Laser Target]]
			end
			if not canSpot and weaponCfg.ManualSpot or weaponCfg.AutoSpot then
				canSpot = true

				if weaponCfg.ManualSpot and weaponCfg.ManualKeybind then
					controlString = controlString..
						[[<br/><b><font color="]]..color2..[[">]]..weaponCfg.ManualKeybind.Name..[[</font></b> Spot target (Cursor)]]
				end
				if weaponCfg.AutoSpot and weaponCfg.AutoKeybind then
					controlString = controlString..
						[[<br/><b><font color="]]..color2..[[">]]..weaponCfg.AutoKeybind.Name..[[</font></b> Spot target (Targeting Data)]]
				end
			end
		end
	end
	ControlText.Controls.TextColor3 = color3
	ControlText.Controls.Text = controlString.."<br/><br/>Click to hide controls."

	if UserInput.KeyboardEnabled==false then
		script.Parent.Controls.Visible = false
		script.Parent.Controls.Interactable = false
	else
		script.Parent.Controls.Interactable = true
	end
end

local function getHumanoid()
	local character = LocalPlayer and LocalPlayer.Character
	if character then
		for _,child in pairs(character:GetChildren()) do
			if child:IsA('Humanoid') then
				return child
			end
		end
	end
end

local function splitNumber(number, startLength) --thanks AI for doing the stuff im too lazy for
	local numberStr = tostring(number)
	local leadingZeros = ""
	local restOfNumber = numberStr

	-- Calculate the number of leading zeros needed
	local totalLength = startLength
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

local function onHeartbeat()
	if CurrentVehicleSeat and CurrentVehicle then
		local speed = UNITS[currentUnits].scaling * CurrentVehicleSeat.Velocity.Magnitude
		local speedDigits = splitNumber(math.min(math.floor(speed), 9999), 3) 

		if CurrentVehicle and CurrentVehicle:GetAttribute("Car_Running")==true then
			SpeedText.TextColor3 = Color3.new(1, 1, 1)
		elseif CurrentVehicle and CurrentVehicle:GetAttribute("Car_Running")==false then
			SpeedText.TextColor3 = Color3.new(0.533333, 0.533333, 0.533333)
		else
			SpeedText.TextColor3 = Color3.new(1, 1, 1)
		end
		SpeedText.Text = [[<font transparency="0.5">]]..speedDigits[1]..[[</font>]]..speedDigits[2]
		SpeedUnit.Text = UNITS[currentUnits].units..":"

		--Fuel label
		local fuelRatio = CurrentVehicle:GetAttribute("Fuel_Current") / CurrentVehicle:GetAttribute("Fuel_Max")
		local fuelDigits = splitNumber(math.min(math.ceil(fuelRatio * 100), 9999), 3) 
		FuelText.Text = [[<font transparency="0.5">]]..fuelDigits[1]..[[</font>]]..fuelDigits[2].."%"

		if fuelRatio*100 < 10 then
			FuelText.TextColor3 = Color3.new(1, 0.2, 0.2)
			FuelText.Parent.Icon.ImageColor3 = Color3.new(1, 0.2, 0.2)
		elseif fuelRatio*100 < 25 then
			FuelText.TextColor3 = Color3.new(1, 0.65, 0.35)
			FuelText.Parent.Icon.ImageColor3 = Color3.new(1, 0.65, 0.35)
		else
			FuelText.TextColor3 = Color3.new(1, 1, 1)
			FuelText.Parent.Icon.ImageColor3 = Color3.new(1, 1, 1)
		end

		-- CurrentVehicleSeat.Parent.Parent.Parent

		--HP label
		local hpRatio = CurrentVehicle:GetAttribute("Vehicle_HP") / CurrentVehicle:GetAttribute("Vehicle_MaxHP")
		local hpDigits = splitNumber(math.min(math.floor(CurrentVehicle:GetAttribute("Vehicle_HP")), 9999), 4) 
		HPText.Text = [[<font transparency="0.5">]]..hpDigits[1]..[[</font>]]..hpDigits[2]

		if hpRatio*100 < 25 then
			HPText.TextColor3 = Color3.new(1, 0.2, 0.2)
			HPText.Parent.Icon.ImageColor3 = Color3.new(1, 0.2, 0.2)
		elseif hpRatio*100 < 50 then
			HPText.TextColor3 = Color3.new(0.980392, 0.956863, 0.317647)
			HPText.Parent.Icon.ImageColor3 = Color3.new(0.980392, 0.956863, 0.317647)
		else
			HPText.TextColor3 = Color3.new(1, 1, 1)
			HPText.Parent.Icon.ImageColor3 = Color3.new(1, 1, 1)
		end
	end
end

local function onSeated(active, currentSeatPart)
	if active then
		if currentSeatPart and currentSeatPart:IsA('VehicleSeat') and currentSeatPart.Parent and currentSeatPart.Parent.Parent and currentSeatPart.Parent.Parent.Parent then
			local tempVehicle = currentSeatPart.Parent.Parent.Parent
			local tempVehicle2 = currentSeatPart.Parent.Parent

			if tempVehicle:HasTag("Okami_Chassis") then
				CurrentVehicleSeat = currentSeatPart
				CurrentVehicle = tempVehicle
				script.Parent.Drive.Visible = true
				script.Parent.Controls.Interactable = true
				script.Parent.Controls.Visible = true
				script.Parent.Controls.Controls.Visible = true
				VehicleSeatHeartbeatCn = RunService.Heartbeat:connect(onHeartbeat)

				if CurrentVehicle then
					setControls(CurrentVehicle, CurrentVehicleSeat, true)
					local vName = CurrentVehicle:GetAttribute("Car_Model")
					local vBrand = CurrentVehicle:GetAttribute("Car_Brand")
					if vName and vBrand then
						coroutine.wrap(function()
							VehicleName.Label.TextTransparency = 0
							VehicleName.Label.Text = vBrand.."<br/>"..vName
							task.wait(2)
							twVicName:Play()
						end)()
					end
				end
			elseif tempVehicle:HasTag("Dragoon_Vehicle") or tempVehicle2:HasTag("Dragoon_Vehicle") then
				CurrentVehicleSeat = currentSeatPart
				CurrentVehicle = tempVehicle2
				script.Parent.Controls.Interactable = true
				script.Parent.Controls.Visible = true
				script.Parent.Controls.Controls.Visible = true

				setControls(CurrentVehicle, currentSeatPart, false)
				local vName = CurrentVehicle:GetAttribute("Car_Model")
				local vBrand = CurrentVehicle:GetAttribute("Car_Brand")
				if vName and vBrand then
					coroutine.wrap(function()
						VehicleName.Label.TextTransparency = 0
						VehicleName.Label.Text = vBrand.."<br/>"..vName
						task.wait(2)
						twVicName:Play()
					end)()
				end
			end
		end
	else
		if CurrentVehicleSeat then
			script.Parent.Drive.Visible = false
			script.Parent.Controls.Interactable = false
			script.Parent.Controls.Visible = false
			script.Parent.MobileControl.Visible = false
			CurrentVehicleSeat = nil
			CurrentVehicle = nil
			if VehicleSeatHeartbeatCn then
				VehicleSeatHeartbeatCn:disconnect()
				VehicleSeatHeartbeatCn = nil
			end
		end
	end
end

SpeedUnit.Activated:Connect(switchUnit)
ControlText.Toggle.Activated:Connect(switchControls)

local function connectSeated()
	local humanoid = getHumanoid()
	while not humanoid do
		task.wait()
		humanoid = getHumanoid()
	end
	humanoid.Seated:connect(onSeated)
end
if LocalPlayer.Character then
	connectSeated()
end
LocalPlayer.CharacterAdded:connect(function(character)
	onSeated(false)
	connectSeated()
end)