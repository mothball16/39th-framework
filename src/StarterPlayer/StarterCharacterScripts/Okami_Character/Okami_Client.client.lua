--[[       
INTERACTIVE SYSTEM
Okami_DD
1.4.3

original chassis by Gamer_Okami
modified and modularized by Jarr (@SrJarr) aka jarr__
compatible with Dragoon Tank System 1.1.2

RELEASED FOR FREE - DRAGOON'S DEN
--]]

local UserInputService = game:GetService("UserInputService");
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService");
local collection = game:GetService("CollectionService");
local vehicles = workspace:WaitForChild("Vehicles");
local camera = workspace.CurrentCamera;
local character = script.Parent.Parent;
local humanoid = character:WaitForChild("Humanoid");

local seatConnection;
local vehicleConnection;
local inputConnection;
local inputConnection2; 
local inputConnection3 = {}
local animationTrack;
local vehicleSeat;
local vehicle;

local mobileControls = game.Players.LocalPlayer.PlayerGui.Okami_UI.MobileControl
local strobeStep = 0

local flipWait = tick()
local flipDB; 
local tankSteerFactor = 1  -- steering divided by this
local promptDisabler = true --fixes the proximityPrompts sometimes showing

local amphibFunctions = false --Disable built in amphib functions because we use a separate system now.

local function getVehicleSpeed()
	return vehicleSeat.CFrame.LookVector:Dot(vehicleSeat.Velocity);
end

local function getBackWheelSize()
	for each, wheel in pairs(vehicle.Functional.Wheels:GetChildren()) do
		if wheel:GetAttribute("WheelType") == "Back" then
			return wheel.Size.Y
		end
	end
end

local function isVehicleOperational()
	if vehicle:GetAttribute("Car_Fueling") then
		return false;
	end
	if vehicle:GetAttribute("Car_Disabled") then
		return false;
	end
	if vehicle:GetAttribute("Vehicle_Underwater")==true and vehicle:GetAttribute("Vehicle_Amphib")~=true then
		return false;
	end
	return vehicle:GetAttribute("Car_Running");
end

local function isUnderwater(vehicle, mass)
	if vehicle:GetAttribute("Vehicle_Underwater")==nil or not amphibFunctions then return end

	local underwater = true
	for _, attach in pairs(mass:GetChildren()) do
		if attach.Name~="UnderwaterProp" then continue end

		local pos = attach.WorldCFrame.Position
		local min = Vector3.new(pos.X + 0.01,pos.Y + 0.01, pos.Z + 0.01)
		local max = Vector3.new(pos.X - 0.01,pos.Y - 0.01, pos.Z - 0.01)

		local region = Region3.new(max, min)
		region = region:ExpandToGrid(4)

		if region then
			local material = game.Workspace.Terrain:ReadVoxels(region, 4)
			if material[1][1][1] == Enum.Material.Water then

			else
				underwater = false
			end
		end
	end

	vehicle:SetAttribute("Vehicle_Underwater", underwater)
end

local function autoflip(mass)
	local gyro = mass:FindFirstChild("AutoFlip")
	if not gyro then return end

	--Detect Orientation
	if (mass.CFrame*CFrame.Angles(math.pi/2,0,0)).lookVector.y > .2 or flipDB then
		flipWait=tick()
	else
		if tick()-flipWait>=3 then
			flipDB=true
			gyro.maxTorque = Vector3.new(10000,0,10000)
			gyro.P=3000
			gyro.D=500
			wait(1)
			gyro.maxTorque = Vector3.new(0,0,0)
			gyro.P=0
			gyro.D=0
			flipDB=false
		end
	end
end

local function getAngularVelocity()
	if vehicle:GetAttribute("Fuel_Current") > 0 and isVehicleOperational() then
		local throttleDirection = math.sign(vehicleSeat.ThrottleFloat);
		local backWheelSize = getBackWheelSize();
		if throttleDirection == 1 then
			return throttleDirection * (vehicle:GetAttribute("Speed_MaxForward") / (backWheelSize / 2))
		else
			return throttleDirection * (vehicle:GetAttribute("Speed_MaxBackward") / (backWheelSize / 2))
		end
	else
		return 0;
	end
end

local function getVehicleTorque()
	if vehicle then -- Vanguard added 5/4/2025: checks if vehicle exists before running this function
		if vehicleSeat then
			local torque = math.abs(vehicleSeat.ThrottleFloat) * vehicle:GetAttribute("Car_Torque");
			if torque == 0 then
				torque = vehicle:GetAttribute("Car_Torque");
			end
			return torque;
		else
			return vehicle:GetAttribute("Car_Torque");
		end
	else
		warn("no vehicle found to check torque for")
	end
end

local function vehicleIsBraking()
	if vehicleSeat then
		if math.sign(vehicleSeat.ThrottleFloat) == 1 and math.sign(getVehicleSpeed()) == -1 then
			return true;
		end
		if math.sign(vehicleSeat.ThrottleFloat) == -1 and math.sign(getVehicleSpeed()) == 1 then
			return true;
		end
	end
end

local function togglePrompts(toggle)
	for each, seat in pairs(vehicle.Functional.Seats:GetChildren()) do
		local prompt = seat:FindFirstChildWhichIsA("ProximityPrompt")
		if prompt then seat.ProximityPrompt.Enabled = toggle; end
	end
	for each, pump in pairs(collection:GetTagged("Okami_GasPump")) do
		local trigger = pump:FindFirstChild("Trigger")
		if not trigger then continue end

		local clicky = trigger:FindFirstChildWhichIsA("ClickDetector") 
		if clicky then
			clicky.HighlightEnabled.Value = toggle;
		end

		local prompt = trigger:FindFirstChildWhichIsA("ProximityPrompt")
		if prompt then
			prompt:SetAttribute("Highlight_Enabled", false)
			prompt.Enabled = toggle
		end
	end
end

local function updateWheel(wheel)
	if wheel.CylindricalConstraint.AngularActuatorType == Enum.ActuatorType.None then wheel.CylindricalConstraint.AngularActuatorType = Enum.ActuatorType.Motor end

	local throttleMult = wheel:GetAttribute("Throttle_Mult") or 1
	if vehicle:GetAttribute("Vehicle_Underwater")==true then
		wheel.CylindricalConstraint.MotorMaxTorque = 0
		wheel.CylindricalConstraint.AngularVelocity = 0
		return
	end

	wheel.CylindricalConstraint.MotorMaxTorque = getVehicleTorque();
	wheel.CylindricalConstraint.AngularVelocity = getAngularVelocity();
	if vehicleIsBraking() then
		wheel.CylindricalConstraint.MotorMaxTorque = vehicle:GetAttribute("Car_BrakingTorque");
		wheel.CylindricalConstraint.MotorMaxAngularAcceleration = vehicle:GetAttribute("Car_BrakingAcceleration");
		coroutine.wrap(function()
			repeat task.wait(); until not vehicleIsBraking();
			wheel.CylindricalConstraint.MotorMaxTorque = getVehicleTorque();
			wheel.CylindricalConstraint.MotorMaxAngularAcceleration = vehicle:GetAttribute("Car_ForwardAcceleration")*throttleMult;
		end)()
	else
		wheel.CylindricalConstraint.MotorMaxTorque = getVehicleTorque();
		wheel.CylindricalConstraint.MotorMaxAngularAcceleration = vehicle:GetAttribute("Car_ForwardAcceleration")*throttleMult;
	end
end

local function updateBackWheels()
	for each, wheel in pairs(vehicle.Functional.Wheels:GetChildren()) do
		if wheel:GetAttribute("WheelType") == "Back" and wheel:GetAttribute("Wheel_Powered")==nil then
			updateWheel(wheel);
		elseif wheel:GetAttribute("Wheel_Powered")==true then --front wheel drive vics
			updateWheel(wheel);
		else
			wheel.CylindricalConstraint.AngularActuatorType = Enum.ActuatorType.None
		end
	end
end

local function updateFrontWheels(steeringAngle, steerTweenInfo)
	for each, wheel in pairs(vehicle.Functional.Wheels:GetChildren()) do
		local steeringMult = wheel:GetAttribute("Steering_Mult") or 1
		local orientation = Vector3.new(0, steeringAngle*steeringMult, 90);

		if wheel:GetAttribute("WheelType") == "Front" and wheel:GetAttribute("Wheel_TankSteering")~=true and wheel:GetAttribute("Wheel_Steering")==nil then
			TweenService:Create(vehicle.Functional.Mass[wheel.Name], steerTweenInfo, {Orientation = orientation}):Play();
		elseif wheel:GetAttribute("Wheel_Steering")==true then
			TweenService:Create(vehicle.Functional.Mass[wheel.Name], steerTweenInfo, {Orientation = orientation}):Play();
		end
	end

	local suspFixed = vehicle.Functional:FindFirstChild("Susp_Fixed")
	if suspFixed then
		for each, wheel in pairs(suspFixed:GetChildren()) do
			local steeringMult = wheel:GetAttribute("Steering_Mult") or 1
			local orientation = Vector3.new(0, steeringAngle*steeringMult, 90);

			if wheel:GetAttribute("WheelType") == "Front" and wheel:GetAttribute("Wheel_TankSteering")~=true and wheel:GetAttribute("Wheel_Steering")==nil then
				TweenService:Create(vehicle.Functional.Mass[wheel.Name], steerTweenInfo, {Orientation = orientation}):Play();
			elseif wheel:GetAttribute("Wheel_Steering")==true then
				TweenService:Create(vehicle.Functional.Mass[wheel.Name], steerTweenInfo, {Orientation = orientation}):Play();
			end
		end
	end
end

local function updateAngularMovers(vehicle, mass, steering)
	local vehicleWork = isVehicleOperational()
	local isUnderwater = vehicle:GetAttribute("Vehicle_Underwater")

	--Tank steering
	local tankMover:BodyAngularVelocity = mass:FindFirstChild("TankSteering")
	if tankMover and vehicleWork and (not amphibFunctions and not isUnderwater) then
		local inverter = math.sign(vehicleSeat.ThrottleFloat)
		if inverter==0 then inverter = 1 end

		if steering>2 or steering<-2 and vehicleWork then
			tankMover.AngularVelocity = Vector3.new(0, math.rad(steering*tankSteerFactor*inverter), 0)
		elseif steering>=-2 or steering<=2 then
			tankMover.AngularVelocity = Vector3.new(0, 0, 0)
		end
		tankMover.MaxTorque = Vector3.new(0, 999999999, 0)
	elseif tankMover then
		tankMover.AngularVelocity = Vector3.new(0, 0, 0)
		tankMover.MaxTorque = Vector3.new(0, 0, 0)
	end

	--Underwater steering
	local underwaterMover:AngularVelocity = mass:FindFirstChild("UnderwaterSteering")
	if underwaterMover and isUnderwater and amphibFunctions then
		underwaterMover.Enabled = true

		local inverter = math.sign(vehicleSeat.ThrottleFloat)
		if inverter==0 then inverter = 1 end
		local mult = vehicle:GetAttribute("Car_UnderwaterAccMult") or 1

		if steering>2 or steering<-2 and vehicleWork then
			underwaterMover.AngularVelocity = Vector3.new(0, math.rad(steering*tankSteerFactor*inverter*mult), 0)
		elseif steering>=-2 or steering<=2 then
			underwaterMover.AngularVelocity = Vector3.new(0, 0, 0)
		end
	elseif underwaterMover then
		underwaterMover.Enabled = false
	end
end

local function updateLinearMovers(vehicle, mass, throttle)
	local vehicleWork = isVehicleOperational()
	local isUnderwater = vehicle:GetAttribute("Vehicle_Underwater")

	--Underwater throttle
	local underwaterMover:LinearVelocity = mass:FindFirstChild("UnderwaterLinear")
	if underwaterMover and isUnderwater and vehicleWork and amphibFunctions then
		local mult = vehicle:GetAttribute("Car_UnderwaterAccMult") or 1
		underwaterMover.Enabled = true
		underwaterMover.LineVelocity = vehicle:GetAttribute("Car_ForwardAcceleration") * throttle * mult
	elseif underwaterMover then
		underwaterMover.Enabled = false
	end
end

local function keyDown(input:InputObject, gameProcessedEvent)
	if gameProcessedEvent then return end

	local modifier = (typeof(input)=="table" and input.ModifierDown) or input:IsModifierKeyDown(Enum.ModifierKey.Alt)

	if modifier and input.KeyCode == Enum.KeyCode.H or input.KeyCode==Enum.KeyCode.ButtonL3 then
		vehicle.Remotes.RemoteEvent:FireServer("Radio");
	elseif input.KeyCode == Enum.KeyCode.H or input.KeyCode==Enum.KeyCode.ButtonL3 then
		vehicle.Remotes.RemoteEvent:FireServer("Horn");
	elseif input.KeyCode == Enum.KeyCode.T or input.KeyCode==Enum.KeyCode.DPadUp then
		vehicle.Remotes.RemoteEvent:FireServer("Engine");
	elseif input.KeyCode == Enum.KeyCode.C or input.KeyCode==Enum.KeyCode.DPadRight then
		vehicle.Remotes.RemoteEvent:FireServer("HitchToggle");
	elseif input.KeyCode == Enum.KeyCode.Q or input.KeyCode==Enum.KeyCode.ButtonL1 then
		vehicle.Remotes.RemoteEvent:FireServer("LeftIndicator");
	elseif input.KeyCode == Enum.KeyCode.E or input.KeyCode==Enum.KeyCode.ButtonR1 then
		vehicle.Remotes.RemoteEvent:FireServer("RightIndicator");
	elseif input.KeyCode == Enum.KeyCode.X or input.KeyCode==Enum.KeyCode.ButtonR3 then
		vehicle.Remotes.RemoteEvent:FireServer("HazardIndicator");
	elseif input.KeyCode == Enum.KeyCode.L or input.KeyCode==Enum.KeyCode.DPadDown then
		vehicle.Remotes.RemoteEvent:FireServer("Headlight");
	elseif modifier and input.KeyCode == Enum.KeyCode.F then

		if UserInputService.KeyboardEnabled==false then
			if strobeStep>=2 then
				vehicle.Remotes.RemoteEvent:FireServer("StrobeOff");
				strobeStep = 0
			else
				vehicle.Remotes.RemoteEvent:FireServer("Strobe");
				strobeStep += 1
			end
		else
			vehicle.Remotes.RemoteEvent:FireServer("Strobe");
		end

	elseif modifier and input.KeyCode == Enum.KeyCode.V then
		vehicle.Remotes.RemoteEvent:FireServer("StrobeOff");
	elseif modifier and input.KeyCode == Enum.KeyCode.G then --NOTE: Studio has a built in keybind (ALT-G) that conflicts with this, but only in studio testing, not in the real game. So sirens wont work in studio.
		vehicle.Remotes.RemoteEvent:FireServer("Siren");
	end
end

local function keyUp(input, gameProcessedEvent)
	if gameProcessedEvent then return end

	if input.KeyCode == Enum.KeyCode.H then
		vehicle.Remotes.RemoteEvent:FireServer("HornStop");
	end
end

local function MobileKeyEmulation(button, keyPressed)
	local InputObject = 
		{ 
			["KeyCode"] = Enum.KeyCode:FromName(button:GetAttribute("KeyCode")) or nil,
			["UserInputType"] = Enum.UserInputType:FromName(button:GetAttribute("UserInputType")) or Enum.UserInputType.Keyboard,
			["ModifierDown"] = button:GetAttribute("Modifier")
		}
	if keyPressed then
		keyDown(InputObject, false)
	else
		keyUp(InputObject, false)
	end
end

-- VANGUARD ANIMATION FIX ATTEMPT 5/4/2025
local function GetAnimation(human:Humanoid, seat:Seat, okamiVic:boolean)
	if not human then return end
	local animator = human:FindFirstChildOfClass("Animator")
	if not animator then return end

	local animation = okamiVic and seat:FindFirstChildOfClass("Animation")
	local animation2
	local animation2Name = seat:GetAttribute("Animation") or "Seated_Passenger"
	local animTrack

	if human.Parent:FindFirstChild("UpperTorso") then
		animation2 = game.ReplicatedStorage.INTERACT_Assets.Animations.R15:FindFirstChild(animation2Name)
	else
		animation2 = game.ReplicatedStorage.INTERACT_Assets.Animations.R6:FindFirstChild(animation2Name)
	end

	if animation or animation2 then
		animTrack = animator:LoadAnimation(animation or animation2)
		return animTrack
	end
end
-- </VANGUARD ANIMATION FIX ATTEMPT 5/4/2025>

if promptDisabler then
	--Dumb fix to proximityPrompt issues when they were not getting disabled as you entered a seat.
	--Not only are we disabling these from the CustomPrompt script in starterPlayer, we're also doing it here now
	--Suggested by maxanderl in DD server. Thanks!
	humanoid.Seated:Connect(function(active)
		ProximityPromptService.Enabled = not active
	end)
end

character.Humanoid.Seated:Connect(function(seated, seatPart)
	if seatConnection then
		seatConnection:Disconnect();
		seatConnection = nil;
	end
	if vehicleConnection then
		vehicleConnection:Disconnect();
		vehicleConnection = nil;
	end
	if inputConnection then
		inputConnection:Disconnect();
		inputConnection = nil;	
	end
	if inputConnection2 then
		inputConnection2:Disconnect();
		inputConnection2 = nil;	
	end
	for each, connection in inputConnection3 do
		if connection~=nil then 
			connection:Disconnect() 
			connection = nil
		end
	end
	if animationTrack then
		animationTrack:Stop();
		animationTrack = nil;
	end

	if seatPart then 
		local tempVehicle = seatPart.Parent and seatPart.Parent.Parent and seatPart.Parent.Parent.Parent --NON-OKAMI SEAT FIX
		if not tempVehicle or not tempVehicle:HasTag("Okami_Chassis") then 

			--Not the driver of any okami vehicle, but the seat might still need to be animated
			animationTrack = GetAnimation(humanoid, seatPart, false)
			if animationTrack then animationTrack:Play() end

			return 
		end

		vehicle = tempVehicle
		vehicleSeat = seatPart

		--Play animations on seats with "Animation attribute"
		animationTrack = GetAnimation(humanoid, vehicleSeat, true)
		if animationTrack then animationTrack:Play() end

		camera.CameraSubject = humanoid;

		if vehicle.Functional.Mass.Radio:FindFirstChild("EqualizerSoundEffect") then
			vehicle.Functional.Mass.Radio.EqualizerSoundEffect.Enabled = false;
		end

		--togglePrompts(false);


		if vehicleSeat:IsA("VehicleSeat") then
			--local animation = vehicleSeat:FindFirstChildOfClass("Animation")
			--if animation then
			--	animationTrack = humanoid:LoadAnimation(animation);
			--	animationTrack:Play();
			--end


			local steerTweenInfo = TweenInfo.new(vehicle:GetAttribute("Steering_Time") or 0.4);

			seatConnection = vehicleSeat.Changed:Connect(function(property)
				if property == "SteerFloat" then
					local coefficient = (vehicle:GetAttribute("Steering_FastAngle") - vehicle:GetAttribute("Steering_SlowAngle")) / vehicle:GetAttribute("Speed_MaxForward");
					local steeringAngle = (coefficient * math.abs(getVehicleSpeed())) + vehicle:GetAttribute("Steering_SlowAngle");
					updateFrontWheels(-vehicleSeat.SteerFloat * steeringAngle, steerTweenInfo);
					updateAngularMovers(vehicle, vehicle.Functional.Mass, -vehicleSeat.SteerFloat * steeringAngle)
				elseif property == "ThrottleFloat" then
					isUnderwater(vehicle, vehicle.Functional.Mass)
					updateBackWheels(vehicleSeat.ThrottleFloat);
					updateLinearMovers(vehicle, vehicle.Functional.Mass, vehicleSeat.ThrottleFloat)
				end
				autoflip(vehicle.Functional.Mass)
			end)

			vehicleConnection = vehicle.AttributeChanged:Connect(function(attribute)
				if attribute == "Fuel_Current" then
					if vehicle:GetAttribute("Fuel_Current") <= 0 then
						updateBackWheels();
					end
					isUnderwater(vehicle, vehicle.Functional.Mass)
				elseif attribute == "Car_Fueling" then
					if vehicle:GetAttribute("Car_Fueling") then
						updateBackWheels();
					end
				elseif attribute == "Car_Disabled" then
					if vehicle:GetAttribute("Car_Disabled") then
						updateBackWheels();
					end
				elseif attribute == "Car_Running" then
					if not vehicle:GetAttribute("Car_Running") then
						updateBackWheels();
						updateLinearMovers(vehicle, vehicle.Functional.Mass, 0)
						updateAngularMovers(vehicle, vehicle.Functional.Mass,0)
						isUnderwater(vehicle, vehicle.Functional.Mass)
						autoflip(vehicle.Functional.Mass)
					end
				end
			end)

			inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
				keyDown(input, gameProcessedEvent)
			end)

			inputConnection2 = UserInputService.InputEnded:Connect(function(input, gameProcessedEvent)
				keyUp(input, gameProcessedEvent)
			end)

			--Mobile support
			if UserInputService.KeyboardEnabled==false then
				mobileControls.Visible = true

				for each, button in pairs(mobileControls:GetDescendants()) do
					if not button:IsA("TextButton") then continue end

					table.insert(inputConnection3, button.InputBegan:Connect(function()
						MobileKeyEmulation(button, true)
					end))
					table.insert(inputConnection3, button.InputEnded:Connect(function()
						MobileKeyEmulation(button, false)
					end))
				end
			else
				mobileControls.Visible = false
			end

		end
	elseif vehicleSeat then
		--character.PrimaryPart.CFrame = vehicleSeat.PrimaryExit.WorldCFrame;
		--jarrmod: using another teleport system

		if vehicle and vehicle:FindFirstChild("Functional") then
			local radio = vehicle.Functional.Mass:FindFirstChild("Radio") and vehicle.Functional.Mass.Radio:FindFirstChild("EqualizerSoundEffect")
			if radio then radio.Enabled = true end
		end

		--togglePrompts(true);

		-- VANGUARD ANIMATION FIX ATTEMPT 5/4/2025
		if animationTrack then
			animationTrack:Stop();
			animationTrack = nil;
		end
		-- </VANGUARD ANIMATION FIX ATTEMPT 5/4/2025>

		vehicleSeat = nil;
		vehicle = nil;
	end
end)

-- Fires when the user tries to jump

-- VANGUARD JUMP FIX ATTEMPT 5/4/2025
local function jump()
	if vehicleSeat then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	else
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	end
end
-- </VANGUARD ANIMATION FIX ATTEMPT 5/4/2025>

UserInputService.JumpRequest:Connect(jump)