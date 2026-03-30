--[[       
INTERACTIVE SYSTEM
Okami_DD
1.4.3

original chassis by Gamer_Okami
modified and modularized by Jarr (@SrJarr) aka jarr__
compatible with Dragoon Tank System 1.1.2

RELEASED FOR FREE - DRAGOON'S DEN
--]]

--// Services
local tweens = game:GetService("TweenService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local collection = game:GetService("CollectionService")
local players = game:GetService("Players")
local mod = {}


local dtsInstall = replicatedStorage:FindFirstChild("DTS_Assets") --Dragoon tank system compat
local dtsSetup 
local destroy 
local atmod
if dtsInstall then 
	dtsSetup = require(dtsInstall.Modules.VehicleSetup)
	destroy = require(dtsInstall.Modules.SelfDestruction)
	atmod = require(dtsInstall.Modules.Antitank)
end

mod.InitializeWithCoroutine = false
mod.RunWithCoroutine = false
mod.RunTags = 
	{ --tag, function to run
		["Okami_Chassis"] = "SetupCar",
		["Okami_GasPump"] = "SetupGasPump",
		["Okami_RegenPad"] = "SetupRegenPad"
	}

--// Stuff
local assets = replicatedStorage.INTERACT_Assets
local misc = assets.Modules:FindFirstChild("Misc") and require(assets.Modules.Misc)
local resupply = assets.Modules:FindFirstChild("Resupply") and require(assets.Modules.Resupply)
local fchat = assets.Modules:FindFirstChild("FactionChat") and require(assets.Modules.FactionChat)
local notifMod = require(assets.Modules.NotifModule)

local hitchParams = OverlapParams.new()
hitchParams.FilterType = Enum.RaycastFilterType.Exclude

local remoteCooldowns = {};
local defaultRadio = {
	9043887091, --Lo-fi Chill A
	1845341094, --Chill Jazz
	75793628822368, --Mirage Portal
	14145620056, --Phonk Vol. 2
	7024220835, --Nitro Fun
	9047105702, --Light Dreamer
	9047050075, --Lo Fi Dreams
	9046862383, --Birdland
	9046864914, --Vintage dreams
}
local lightNames = {
	["Head"] = {"Head", "F"},
	["Tail"] = {"Tail", "R"},
	["Reverse"] = {"Reverse","RV"},
	["Left"] = {"Hazards","Left","LeftIndicator", "FLI", "RLI"},
	["Right"] = {"Hazards","Right","RightIndicator", "FRI", "RRI"},
	["Hazards"] = {"Hazards","LeftIndicator", "FLI", "RLI", "RightIndicator", "FRI", "RRI"},
	["Strobe1"] = {"Strobe1"},
	["Strobe2"] = {"Strobe2"},
}
local neonLights = true

--// Functions
local function initializeCollisions()
	game.PhysicsService:RegisterCollisionGroup("VehicleBody")
	game.PhysicsService:RegisterCollisionGroup("VehicleWheels")
	game.PhysicsService:RegisterCollisionGroup("VehicleTurret")
	game.PhysicsService:RegisterCollisionGroup("VehicleGun")
	game.PhysicsService:CollisionGroupSetCollidable("VehicleBody","VehicleTurret",false)
	game.PhysicsService:CollisionGroupSetCollidable("VehicleBody","VehicleGun",false)
	game.PhysicsService:CollisionGroupSetCollidable("VehicleTurret","VehicleGun",false)
	game.PhysicsService:CollisionGroupSetCollidable("VehicleBody","VehicleWheels",false)
	game.PhysicsService:CollisionGroupSetCollidable("VehicleTurret","VehicleWheels",false)
	game.PhysicsService:CollisionGroupSetCollidable("VehicleGun","VehicleWheels",false)
	game.PhysicsService:CollisionGroupSetCollidable("Default", "VehicleTurret", false)
	game.PhysicsService:CollisionGroupSetCollidable("Default", "VehicleWheels", true)
	game.PhysicsService:CollisionGroupSetCollidable("Default", "VehicleBody", true)
end

local function isOccupied(target)
	for _, Seat in ipairs(target:GetDescendants()) do
		if Seat:IsA("Seat") or Seat:IsA("VehicleSeat") then
			if Seat.Occupant then return true end
		end
	end
end

local function enableLight(lightPart, bool)
	for each, thing in pairs(lightPart:GetChildren()) do
		if thing:IsA("SurfaceLight") or thing:IsA("SpotLight") or thing:IsA("PointLight") then 
			thing.Enabled = bool 
		elseif thing:IsA("Attachment") then
			enableLight(thing, bool)
		end
	end
end

local function runLights(lightOrigin, lightGroup, bool)
	if lightGroup == "All" then
		local retries = {"Head", "Reverse", "Tail", "Hazards", "Strobe1", "Strobe2"}
		for each, retry in retries do
			runLights(lightOrigin, retry, bool)
		end
		return
	elseif lightGroup == "Strobes" then
		local retries = {"Strobe1", "Strobe2"}
		for each, retry in retries do
			runLights(lightOrigin, retry, bool)
		end
		return
	end

	for each, lightPart in pairs(lightOrigin:GetChildren()) do
		if lightPart:IsA("ObjectValue") then lightPart=lightPart.Value end

		--Get the settings
		local materialChange = lightPart.Parent:GetAttribute("LBrick_ChangeMaterial")
		local colorChange = lightPart.Parent:GetAttribute("LBrick_ChangeColor")
		local transparentLighting = lightPart.Parent:GetAttribute("LBrick_Transparent")


		if table.find(lightNames[lightGroup], lightPart.Name)~=nil then
			--Change the color
			if colorChange then
				local attributeName = "LBrick_"..lightNames[lightGroup][1]
				if bool then 
					attributeName = attributeName.."On" 
				else 
					attributeName = attributeName.."Off" 
				end

				local findAttribute = lightPart.Parent:GetAttribute(attributeName)
				if findAttribute then lightPart.Color = findAttribute  end
			end
			--Change material
			if materialChange then
				if bool then
					lightPart.Material = Enum.Material.Neon
				else
					lightPart.Material = Enum.Material.Glass
				end
			end
			
			if transparentLighting then
				if bool then
					lightPart.Transparency = 0
				else
					lightPart.Transparency = 1
				end
			end


			--Toggle lights
			enableLight(lightPart, bool)
		end
	end
end

local function enableExhaust(part, bool)
	for _, thing in pairs(part:GetChildren()) do
		if thing:IsA("ParticleEmitter") then
			thing.Enabled=bool
		elseif thing:IsA("Attachment") and thing.Name=="Exhaust" then
			enableExhaust(thing, bool)
		end
	end
end

local function passedRemoteSecurity(player, arguments, types)
	if not player or not player.Character then
		return false;
	end

	if remoteCooldowns[player] then
		if os.time() - remoteCooldowns[player] < 1 then
			return false;
		end
		remoteCooldowns[player] = os.time();
	else
		remoteCooldowns[player] = os.time();
	end

	for each, argument in pairs(arguments) do
		if typeof(argument) ~= types[each] then
			return false;
		end
		if typeof(argument) ~= typeof(argument) then
			return false;
		end
	end

	return true;
end

local function trailerLights(hitchAttach, vehicle, trailer, delete)
	local vicLights = vehicle.Functional.Lights
	local towLights = trailer.Functional:FindFirstChild("Lights")
	if not towLights then return end

	if not delete then
		for _, lightPart in pairs(towLights:GetChildren()) do
			if not lightPart:IsA("BasePart") then continue end

			local ref1 = Instance.new("ObjectValue")
			ref1.Name = lightPart.Name
			ref1.Value = lightPart
			ref1.Parent = vicLights
			local ref2 = Instance.new("ObjectValue")
			ref2.Name = "vicRef"
			ref2.Value = trailer
			ref2.Parent = ref1
		end
	else
		for _, lightPart in pairs(vicLights:GetChildren()) do
			if not lightPart:IsA("ObjectValue") then continue end

			local ref2 = lightPart:FindFirstChild("vicRef")
			if not ref2 then continue end

			if ref2.Value~=trailer then continue end
			lightPart:Destroy()
		end
	end
end

local function useHitch(hitchAttach: Attachment, vehicle)
	local joint = hitchAttach:FindFirstChildWhichIsA("BallSocketConstraint")
	local prompt = hitchAttach:FindFirstChildWhichIsA("ProximityPrompt")

	if joint then --Disconnect
		trailerLights(hitchAttach, vehicle, joint.Attachment1.Parent.Parent.Parent, true)
		joint.Attachment1.JointRef.Value = nil
		joint:Destroy()
		if prompt then prompt.ActionText = "Attach" end
		hitchAttach.Use:Play()
	else --Not connected, let's connect
		hitchParams.FilterDescendantsInstances = {vehicle}
		local partsNearby = workspace:GetPartBoundsInRadius(hitchAttach.WorldPosition, 6, hitchParams)
		local attachments = {}

		--Get the valid hitches
		for _, part in partsNearby do
			if part.Name~="Mass" then continue end

			local massChildren = part:GetChildren()
			for _, mpart in massChildren do
				if 
					mpart.Name=="Hitch1" and 
					mpart:GetAttribute("Hitch_Type")==hitchAttach:GetAttribute("Hitch_Type") and 
					mpart.JointRef.Value==nil 
				then 
					table.insert(attachments, mpart) 
				end
			end
		end

		local closestHitch
		local closestDist = 3
		for _, hitch1:Attachment in attachments do
			local dist = (hitchAttach.WorldPosition - hitch1.WorldPosition).Magnitude
			if dist<closestDist and hitchAttach.Parent~=hitch1.Parent then
				closestDist = dist
				closestHitch = hitch1
			end
		end

		if closestHitch then
			local ballJoint = Instance.new("BallSocketConstraint")
			ballJoint.Parent = hitchAttach
			ballJoint.Attachment0 = hitchAttach
			ballJoint.Attachment1 = closestHitch
			ballJoint.Enabled = true
			closestHitch.JointRef.Value = ballJoint

			trailerLights(hitchAttach, vehicle, closestHitch.Parent.Parent.Parent, false)

			if prompt then prompt.ActionText = "Deattach" end
			hitchAttach.Use:Play()
		end
	end
end

function mod.initializeTrailer(vehicle)
	for each, thing in vehicle:GetChildren() do
		if thing:HasTag("Okami_GasPump") then
			mod.SetupGasPump(thing)
		elseif thing:HasTag("Okami_RegenPad") then
			mod.SetupRegenPad(thing)
		elseif misc and thing:HasTag("ToolGiver") then
			misc.SetupGiver(thing)
		elseif fchat and thing:HasTag("Radio_Station") then
			fchat.SetupRadioStation(thing)
		elseif resupply and thing:HasTag("Ammobox_SPH") then
			resupply.SetupAmmoBox(thing)
		end
	end
end

local function initializeVehicle(vehicle, functional, seats, wheels, lights)
	local density = vehicle:GetAttribute("Car_Mass") / (functional.Mass.Size.X * functional.Mass.Size.Y * functional.Mass.Size.Z);
	functional.Mass.CustomPhysicalProperties = PhysicalProperties.new(density, 0, 0, 0, 0);

	seats.VehicleSeat.MaxSpeed = vehicle:GetAttribute("Speed_MaxForward");

	local bodyGyro = Instance.new("BodyGyro")
	bodyGyro.P = 0
	bodyGyro.D = 0
	bodyGyro.MaxTorque = Vector3.new(0,0,0)
	bodyGyro.Name = "AutoFlip"
	bodyGyro.Parent = functional.Mass

	mod.initializeTrailer(vehicle)

	for each, thing in pairs(functional.Mass:GetChildren()) do
		if thing:IsA("Attachment") and thing.Name=="Hitch0" then
			local prompt = thing:FindFirstChildWhichIsA("ProximityPrompt")
			if prompt then
				prompt.Triggered:Connect(function()
					useHitch(thing, vehicle)
				end)
			end
		end
	end

	for each, wheel in pairs(wheels:GetChildren()) do
		if wheel:GetAttribute("Wheel_Powered")==true or (wheel:GetAttribute("Wheel_Powered")==nil and wheel:GetAttribute("WheelType")=="Back") then
			wheel.CylindricalConstraint.AngularActuatorType = Enum.ActuatorType.Motor
		else
			wheel.CylindricalConstraint.AngularActuatorType = Enum.ActuatorType.None
		end

		if wheel.CylindricalConstraint.AngularActuatorType == Enum.ActuatorType.Motor then
			wheel.CylindricalConstraint.MotorMaxTorque = vehicle:GetAttribute("Car_Torque");
			wheel.CylindricalConstraint.MotorMaxAngularAcceleration = vehicle:GetAttribute("Car_ForwardAcceleration");
		end

		if wheel:FindFirstChild("SpringConstraint") then
			if vehicle:GetAttribute("Suspension_Automatic") then
				local adjustedMass = vehicle:GetAttribute("Car_Mass") * 1
				local stiffness = (adjustedMass * workspace.Gravity) / vehicle:GetAttribute("Suspension_Height") / #wheels:GetChildren();
				local damping = (2 * math.sqrt(adjustedMass * stiffness) * vehicle:GetAttribute("Suspension_Tuning")) / #wheels:GetChildren();
				vehicle:SetAttribute("Suspension_Stiffness", stiffness);
				vehicle:SetAttribute("Suspension_Damping", damping);
			end
			wheel.SpringConstraint.Damping = vehicle:GetAttribute("Suspension_Damping");
			wheel.SpringConstraint.Stiffness = vehicle:GetAttribute("Suspension_Stiffness");
			wheel.SpringConstraint.FreeLength = vehicle:GetAttribute("Suspension_Height");
		end
	end

	runLights(lights, "All", false)
end

local function findVehicleInRange(pump:Model)
	for _, vehicle in pairs(collection:GetTagged("Okami_Chassis")) do
		if vehicle and vehicle.Functional and vehicle.Functional:FindFirstChild("FuelCap") and vehicle:GetAttribute("Fuel_Infinite")~=true then
			if pump:IsDescendantOf(vehicle) then return end

			if (vehicle.Functional.FuelCap.Position - pump.Func.HoseAnchor.Position).Magnitude <= pump.Func.Handle.RopeConstraint.Length then
				for _, otherPump in ipairs(collection:GetTagged("Okami_GasPump")) do
					if otherPump.Func.Handle.WeldConstraint.Part1 == vehicle.Functional.FuelCap then
						return nil;
					end
				end
				return vehicle, vehicle.Functional.FuelCap;
			end
		end
	end

	for _, targetPump in pairs(collection:GetTagged("Okami_GasPump")) do
		if targetPump and targetPump:FindFirstChild("FuelCap") then
			if pump==targetPump or pump:IsAncestorOf(targetPump.FuelCap) then return end

			if (targetPump.FuelCap.Position - pump.Func.HoseAnchor.Position).Magnitude <= pump.Func.Handle.RopeConstraint.Length then
				for _, otherPump in ipairs(collection:GetTagged("Okami_GasPump")) do
					if otherPump.Func.Handle.WeldConstraint.Part1 == targetPump.FuelCap then
						return nil;
					end
				end
				return targetPump, targetPump.FuelCap;
			end
		end
	end
end

local function weldPump(handle, nozzle, target)
	handle.WeldConstraint.Enabled = false;
	handle.WeldConstraint.Part1 = target;
	nozzle.CFrame = target.CFrame;
	handle.WeldConstraint.Enabled = true;
end

--// Core Functions
function mod.Initialize()
	--// Setup events
	initializeCollisions()

	players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			character.Humanoid.Seated:Connect(function(seated, seatPart)
				if seatPart and seatPart:IsA("VehicleSeat") and seatPart.Parent.Parent.Parent:HasTag("Okami_Chassis") and not seatPart.Parent.Parent.Parent:HasTag("Dragoon_Vehicle") then
					seatPart:SetNetworkOwner(player);
				end
			end)
		end)
	end)
end

function mod.SetupCar(vehicle: Model)
	if vehicle:HasTag("INTERACT_LOADED") then return end
	if not vehicle:IsDescendantOf(game.Workspace) then return end

	--/ Initialize
	coroutine.wrap(function()
		local functional = vehicle.Functional;
		local decorative = vehicle.Decorative;
		local remotes = vehicle.Remotes;
		local seats = functional.Seats;
		local wheels = functional.Wheels;
		local lights = functional.Lights;

		--DTS destruction compat
		if not vehicle:GetAttribute("Vehicle_Name") then
			vehicle:SetAttribute("Vehicle_Name", vehicle:GetAttribute("Car_Model"))
		end

		vehicle:GetAttributeChangedSignal("Vehicle_HP"):Connect(function()
			if vehicle:GetAttribute("Vehicle_HP") <= 0 and not vehicle:HasTag("Dragoon_Destroyed") and destroy then 
				destroy.Explode(vehicle, functional.Mass, functional.Mass, vehicle:GetAttribute("Vehicle_ExplodeFX"))
			end
		end)

		if vehicle:HasTag("Dragoon_Vehicle") and dtsSetup then
			dtsSetup.LoadVic(vehicle)
		elseif not vehicle:HasTag("Dragoon_Vehicle") and atmod then
			local roadkill = {}
			local roadkillTime = 0
			local roadkillTask
			
			for _, funcPart in functional:GetChildren() do
				if funcPart.Name=="MovingHitbox" then
					funcPart.Touched:Connect(function(hitPart)
						if hitPart:IsDescendantOf(vehicle) then return end
						
						roadkillTime = os.clock()

						if roadkillTask then task.cancel(roadkillTask) end
						roadkillTask = task.delay(5, function()
							if os.clock() - roadkillTime >= 5 then
								table.clear(roadkill)
							end
						end)

						--Run code
						local hitVel:number = funcPart.AssemblyLinearVelocity.Magnitude
						local hitMass:number = hitPart.AssemblyMass
						if hitVel<5 or hitMass<5 or table.find(roadkill, hitPart)~=nil then return end

						local plrDriver = seats.VehicleSeat.Occupant -- does this vehicle have a driver?
						local plrKiller = plrDriver and game.Players:GetPlayerFromCharacter(plrDriver.Parent)

						local vicDmg = math.clamp(math.map(hitVel, 0, 20, 0, 50), 0, 50)
						local vicPen = 25
						local plrDmg = math.map(hitVel, 0, 20, 5, 150)
						local knockback = Vector3.new(0,0, -hitVel/5)

						local result = atmod.RoadKill(funcPart, hitPart, plrKiller, roadkill, {vicPen, vicDmg, plrDmg, knockback})
						if result then
							table.insert(roadkill, result)
						end
					end)
				end
			end
		end
		--DTS compat
		initializeVehicle(vehicle, functional, seats, wheels, lights);

		seats.VehicleSeat:GetPropertyChangedSignal("Occupant"):Connect(function()
			if seats.VehicleSeat.Occupant~=nil then
				local driverIn = functional.Mass:FindFirstChild("DriverIn")
				if driverIn then task.wait(1); driverIn:Play() end
			else
				local siren = functional.Mass:FindFirstChild("Siren")
				if siren then siren:Stop() end

				local driverIn = functional.Mass:FindFirstChild("DriverIn")
				if driverIn then driverIn:Stop() end
			end
		end)

		vehicle.AttributeChanged:Connect(function(attribute)
			if attribute == "Car_AlarmID" then
				functional.Mass.Alarm.SoundId = "rbxassetid://"..vehicle:GetAttribute("Car_AlarmID");
			elseif attribute == "Car_HornID" then
				functional.Mass.Horn.SoundId = "rbxassetid://"..vehicle:GetAttribute("Car_HornID");
			elseif attribute == "Car_RadioID" then
				functional.Mass.Radio.SoundId = "rbxassetid://"..vehicle:GetAttribute("Car_RadioID");
			elseif attribute == "Car_Mass" then
				local density = vehicle:GetAttribute("Car_Mass") / (functional.Mass.Size.X * functional.Mass.Size.Y * functional.Mass.Size.Z);
				functional.Mass.CustomPhysicalProperties = PhysicalProperties.new(density, 0, 0, 0, 0);
			elseif attribute == "Car_Torque" then
				for each, wheel in pairs(wheels:GetChildren()) do
					if wheel.CylindricalConstraint.AngularActuatorType == Enum.ActuatorType.Motor then
						wheel.CylindricalConstraint.MotorMaxTorque = vehicle:GetAttribute("Car_Torque");
					end
				end
			elseif attribute == "Car_ForwardAcceleration" then
				for each, wheel in pairs(wheels:GetChildren()) do
					if wheel.CylindricalConstraint.AngularActuatorType == Enum.ActuatorType.Motor then
						wheel.CylindricalConstraint.MotorMaxTorque = vehicle:GetAttribute("Car_ForwardAcceleration");
					end
				end
			elseif string.sub(attribute, 1, 10) == "Suspension" then
				for each, wheel in pairs(wheels:GetChildren()) do
					if wheel:FindFirstChild("SpringConstraint") then
						if vehicle:GetAttribute("Suspension_Automatic") then
							local stiffness = (vehicle:GetAttribute("Car_Mass") * workspace.Gravity) / vehicle:GetAttribute("Suspension_Height") / #wheels:GetChildren();
							local damping = (2 * math.sqrt(vehicle:GetAttribute("Car_Mass") * stiffness) * vehicle:GetAttribute("Suspension_Tuning")) / #wheels:GetChildren();
							vehicle:SetAttribute("Suspension_Stiffness", stiffness);
							vehicle:SetAttribute("Suspension_Damping", damping);
						end
						wheel.SpringConstraint.Damping = vehicle:GetAttribute("Suspension_Damping");
						wheel.SpringConstraint.Stiffness = vehicle:GetAttribute("Suspension_Stiffness");
						wheel.SpringConstraint.FreeLength = vehicle:GetAttribute("Suspension_Height");
					end
				end
			elseif attribute == "Speed_MaxForward" then
				seats.VehicleSeat.MaxSpeed = vehicle:GetAttribute("Speed_MaxForward");
			elseif attribute == "Car_Running" then
				while vehicle:GetAttribute("Car_Running") do
					local vehicleSpeed = seats.VehicleSeat.CFrame.LookVector:Dot(seats.VehicleSeat.Velocity);

					if not vehicle:GetAttribute("Car_Fueling") then
						if not functional.Mass.Engine.Playing then
							functional.Mass.Engine:Play();
						end

						local startEnginePitch = vehicle:GetAttribute("Car_EngineRevPitch") or 1
						local totalEngPitchMult = vehicle:GetAttribute("Car_EngineRevPitchMult") or 1
						functional.Mass.Engine.PlaybackSpeed = ((math.abs(vehicleSpeed) / vehicle:GetAttribute("Speed_MaxForward"))*totalEngPitchMult) + startEnginePitch;

						if not vehicle:GetAttribute("Fuel_Infinite") then
							local fuelLoss = 0.0005 * math.max(math.abs(vehicleSpeed), 1) * (100 - vehicle:GetAttribute("Fuel_Efficiency"));
							vehicle:SetAttribute("Fuel_Current", vehicle:GetAttribute("Fuel_Current") - fuelLoss);
							if vehicle:GetAttribute("Fuel_Current") < 0 then
								vehicle:SetAttribute("Fuel_Current", 0);
								vehicle:SetAttribute("Car_Running", false);
							end
						end
					end

					local suspFixed = vehicle.Functional:FindFirstChild("Susp_Fixed")
					if suspFixed then
						for each, wheel in pairs(suspFixed:GetChildren()) do
							if wheel:GetAttribute("Wheel_TankSteering")==true then
								local trackFX = wheel:GetChildren()
								for each, trackbeam in pairs(trackFX) do
									if trackbeam:IsA("Beam") and trackbeam:GetAttribute("TrackBeam_Reversed")~=nil then
										local mult = -2
										if trackbeam:GetAttribute("TrackBeam_Reversed")==true then mult = -mult end
										trackbeam.TextureSpeed = vehicleSpeed / mult
									end
								end
							end
						end
					end

					if (seats.VehicleSeat.Throttle == 0 or math.sign(vehicleSpeed) ~= seats.VehicleSeat.Throttle) and math.abs(vehicleSpeed)>2 then
						runLights(lights, "Tail", true)
					else
						runLights(lights, "Tail", false)
					end

					if vehicleSpeed < -2 then
						runLights(lights, "Reverse", true)
					else
						runLights(lights, "Reverse", false)
					end
					task.wait(0.1);
				end

				local engineOn = functional.Mass:FindFirstChild("Ignition") or functional.Mass:FindFirstChild("EngineOn")
				local engineOff = functional.Mass:FindFirstChild("EngineOff")
				functional.Mass.Engine:Stop();
				engineOn:Stop();
				if engineOff then engineOff:Play(); end

				runLights(lights, "Tail", false)
				runLights(lights, "Reverse", false)

				local suspFixed = vehicle.Functional:FindFirstChild("Susp_Fixed")
				if suspFixed then
					for each, wheel in pairs(suspFixed:GetChildren()) do
						if wheel:GetAttribute("Wheel_TankSteering")==true then
							local trackFX = wheel:GetChildren()
							for each, trackbeam in pairs(trackFX) do
								if trackbeam:IsA("Beam") and trackbeam:GetAttribute("TrackBeam_Reversed")~=nil then
									trackbeam.TextureSpeed = 0
								end
							end
						end
					end
				end
			end
		end)

		remotes.RemoteEvent.OnServerEvent:Connect(function(player, action)
			--local passed = passedRemoteSecurity(player, {action}, {"string"});
			--if passed then
			if seats.VehicleSeat.Occupant == player.Character.Humanoid then
				if action == "Horn" then
					functional.Mass.Horn:Play();
				elseif action == "HornStop" then
					functional.Mass.Horn:Stop();
				elseif action == "HitchToggle" then
					for each, thing in pairs(functional.Mass:GetChildren()) do
						if thing:IsA("Attachment") and thing.Name=="Hitch0" then
							if vehicle:GetAttribute("Car_CanTow")==true and thing:GetAttribute("Hitch_SeatKey")==true then
								useHitch(thing, vehicle)
							end
						end
					end
				elseif action == "Engine" then
					if not vehicle:GetAttribute("Car_Running") and not vehicle:GetAttribute("Car_Fueling") and vehicle:GetAttribute("Fuel_Current") > 0 then

						local engineOn = functional.Mass:FindFirstChild("Ignition") or functional.Mass:FindFirstChild("EngineOn")
						engineOn:Play();

						task.wait(vehicle:GetAttribute("Car_IgnitionTime") or 1);

						local driverIn = functional.Mass:FindFirstChild("DriverIn")
						if driverIn then driverIn:Stop() end

						vehicle:SetAttribute("Car_Running", true);
						enableExhaust(functional.Mass, true)
					else
						vehicle:SetAttribute("Car_Running", false);
						enableExhaust(functional.Mass, false)
					end
				elseif action == "LeftIndicator" then
					if vehicle:GetAttribute("Internal_Indicator") == "Left" then
						vehicle:SetAttribute("Internal_Indicator", "Off");
						runLights(lights, "Hazards", false)
					else
						vehicle:SetAttribute("Internal_Indicator", "Left");
						while vehicle:GetAttribute("Internal_Indicator") == "Left" do
							runLights(lights, "Left", true)
							runLights(lights, "Right", false)
							functional.Mass.Indicator:Play();

							task.wait(0.5);

							if vehicle:GetAttribute("Internal_Indicator") == "Left" then
								runLights(lights, "Hazards", false)
								task.wait(0.5);
							end
						end
					end
				elseif action == "RightIndicator" then
					if vehicle:GetAttribute("Internal_Indicator") == "Right" then
						vehicle:SetAttribute("Internal_Indicator", "Off");
						runLights(lights, "Hazards", false)
					else
						vehicle:SetAttribute("Internal_Indicator", "Right");
						while vehicle:GetAttribute("Internal_Indicator") == "Right" do
							runLights(lights, "Left", false)
							runLights(lights, "Right", true)
							functional.Mass.Indicator:Play();

							task.wait(0.5);

							if vehicle:GetAttribute("Internal_Indicator") == "Right" then
								runLights(lights, "Hazards", false)
								task.wait(0.5);
							end
						end
					end
				elseif action == "HazardIndicator" then
					if vehicle:GetAttribute("Internal_Indicator") == "Hazard" then
						vehicle:SetAttribute("Internal_Indicator", "Off");
						runLights(lights, "Hazards", false)
					else
						vehicle:SetAttribute("Internal_Indicator", "Hazard");
						while vehicle:GetAttribute("Internal_Indicator") == "Hazard" do
							runLights(lights, "Hazards", true)
							functional.Mass.Indicator:Play();

							task.wait(0.5);

							if vehicle:GetAttribute("Internal_Indicator") == "Hazard" then
								runLights(lights, "Hazards", false)
								task.wait(0.5);
							end
						end
					end
				elseif action == "Headlight" then
					if vehicle:GetAttribute("Internal_Headlight") then
						runLights(lights, "Head", false)
					else
						runLights(lights, "Head", true)
					end
					vehicle:SetAttribute("Internal_Headlight", not vehicle:GetAttribute("Internal_Headlight"));
				elseif action == "Radio" then
					functional.Mass.RadioClick:Play();
					if functional.Mass.Radio.Volume == 0 then
						task.wait(functional.Mass.RadioClick.TimeLength);
						functional.Mass.Radio.Volume = 1;
					else
						functional.Mass.Radio.Volume = 0;
					end
					if not functional.Mass.Radio.Playing then
						functional.Mass.Radio:Play();
					end
				elseif action == "Strobe" then
					if lights:FindFirstChild("Strobe1") then
						vehicle:SetAttribute("Internal_Strobe", vehicle:GetAttribute("Internal_Strobe") + 1);
						if vehicle:GetAttribute("Internal_Strobe") > 3 then
							vehicle:SetAttribute("Internal_Strobe", 1);
						end

						if vehicle:GetAttribute("Internal_Strobe") == 1 then
							while vehicle:GetAttribute("Internal_Strobe") == 1 do
								if vehicle:GetAttribute("Internal_Strobe") == 1 then
									runLights(lights, "Strobe1", true)
									runLights(lights, "Strobe2", false)
								end

								task.wait(0.15);

								if vehicle:GetAttribute("Internal_Strobe") == 1 then
									runLights(lights, "Strobe1", false)
									runLights(lights, "Strobe2", true)
								end

								task.wait(0.15);
							end
						elseif vehicle:GetAttribute("Internal_Strobe") == 2 then
							while vehicle:GetAttribute("Internal_Strobe") == 2 do
								if vehicle:GetAttribute("Internal_Strobe") == 2 then
									runLights(lights, "Strobe1", true)
									runLights(lights, "Strobe2", false)
								end
								task.wait(0.1);
								if vehicle:GetAttribute("Internal_Strobe") == 2 then
									runLights(lights, "Strobes", false)
								end
								task.wait(0.1);
								if vehicle:GetAttribute("Internal_Strobe") == 2 then
									runLights(lights, "Strobe1", true)
									runLights(lights, "Strobe2", false)
								end
								task.wait(0.1);
								if vehicle:GetAttribute("Internal_Strobe") == 2 then
									runLights(lights, "Strobes", false)
								end
								task.wait(0.1);
								if vehicle:GetAttribute("Internal_Strobe") == 2 then
									runLights(lights, "Strobe1", false)
									runLights(lights, "Strobe2", true)
								end
								task.wait(0.1);
								if vehicle:GetAttribute("Internal_Strobe") == 2 then
									runLights(lights, "Strobes", false)
								end
								task.wait(0.1);

								if vehicle:GetAttribute("Internal_Strobe") == 2 then
									runLights(lights, "Strobe1", false)
									runLights(lights, "Strobe2", true)
								end

								task.wait(0.1);

								if vehicle:GetAttribute("Internal_Strobe") == 2 then
									runLights(lights, "Strobes", false)
								end

								task.wait(0.1);
							end
						elseif vehicle:GetAttribute("Internal_Strobe") == 3 then
							runLights(lights, "Strobe1", true)
							runLights(lights, "Strobe2", false)
						end
					end
				elseif action == "StrobeOff" then
					if lights:FindFirstChild("Strobe1") then
						vehicle:SetAttribute("Internal_Strobe", 0);
						runLights(lights, "Strobes", false)
					end
				elseif action == "Siren" then
					if functional.Mass:FindFirstChild("Siren") then
						if not functional.Mass.Siren.Playing then
							functional.Mass.Siren:Play();
						else
							functional.Mass.Siren:Stop();
						end
					end
				end
			end
			--end
		end)

		functional.Mass.Radio.SoundId = "rbxassetid://"..defaultRadio[vehicle:GetAttribute("Car_RadioStep")];
		functional.Mass.Radio.Loaded:Wait();
		functional.Mass.Radio.TimePosition = 0;
		functional.Mass.Radio:Play();
		functional.Mass.Radio.Ended:Connect(function()
			if vehicle:GetAttribute("Car_RadioStation") == "Default" then
				vehicle:SetAttribute("Car_RadioStep", vehicle:GetAttribute("Car_RadioStep") + 1);
				if vehicle:GetAttribute("Car_RadioStep") > #defaultRadio then
					vehicle:SetAttribute("Car_RadioStep", 1);
				end

				functional.Mass.Radio.SoundId = "rbxassetid://"..defaultRadio[vehicle:GetAttribute("Car_RadioStep")];
				functional.Mass.Radio.Loaded:Wait();
				functional.Mass.Radio.TimePosition = 0;
				functional.Mass.Radio:Play();
			end
		end)

		vehicle:AddTag("INTERACT_LOADED")
	end)()
end

function mod.SetupGasPump(pump: Model)
	if pump:HasTag("INTERACT_LOADED") then return end
	if not pump:IsDescendantOf(game.Workspace) then return end
	
	--/ Initialize
	local trigger = pump.Trigger
	local handle = pump.Func.Handle
	local nozzle = pump.Func.Nozzle
	local sign = pump.Func.Sign
	local vehicle
	local fuelcap

	sign.SurfaceGui.Type.Text = pump:GetAttribute("Pump_Type");
	sign.SurfaceGui.Cost.Text = string.format("$%.2f", pump:GetAttribute("Pump_Cost")).." / "..pump:GetAttribute("Pump_Amount").." units";
	sign.SurfaceGui.Pumped.Text = "";

	local click:ClickDetector = trigger:FindFirstChildWhichIsA("ClickDetector")
	if click then
		click.MouseClick:Connect(function(player)
			if not pump:GetAttribute("Pump_Connected") then
				vehicle, fuelcap = findVehicleInRange(pump);
				if vehicle then
					local vicFuelType = vehicle:GetAttribute("Fuel_Type") or vehicle:GetAttribute("Pump_Type")
					local pumpFuelType = pump:GetAttribute("Pump_Type")
					if (vicFuelType~=nil and vicFuelType~=pumpFuelType) or (vicFuelType==nil and not (pumpFuelType=="Standard" or pumpFuelType==nil)) then return end
					if vehicle:GetAttribute("Fuel_Infinite")==true then return end

					pump:SetAttribute("Pump_Connected", true);
					click:SetAttribute("CursorText", "Unhook from vehicle")
					weldPump(handle, nozzle, fuelcap);
				elseif not vehicle then
					notifMod.Notificate(player, false, "LowerMid", 3, "Hose not long enough to reach closest car!")
				end
			elseif pump:GetAttribute("Pump_Connected") then
				pump:SetAttribute("Pump_Connected", false);
				vehicle = nil
				fuelcap = nil
				click:SetAttribute("CursorText", "Hook from vehicle")
				weldPump(handle, nozzle, pump.Func.HandleStorage);
			end
		end)
	end
	local prompt:ProximityPrompt = trigger:FindFirstChildWhichIsA("ProximityPrompt")
	if prompt then
		prompt.Triggered:Connect(function(player)
			if not pump:GetAttribute("Pump_Connected") then
				vehicle, fuelcap = findVehicleInRange(pump);
				if vehicle then
					pump:SetAttribute("Pump_Connected", true);
					prompt.ActionText = "Unhook from vehicle"
					weldPump(handle, nozzle, fuelcap);
				elseif not vehicle then
					notifMod.Notificate(player, false, "LowerMid", 3, "Hose not long enough to reach closest car!")
				end
			elseif pump:GetAttribute("Pump_Connected") then
				pump:SetAttribute("Pump_Connected", false);
				vehicle = nil
				fuelcap = nil
				prompt.ActionText = "Hook to vehicle"
				weldPump(handle, nozzle, pump.Func.HandleStorage);
			end
		end)
	end

	pump:GetAttributeChangedSignal("Pump_Connected"):Connect(function()
		if pump:GetAttribute("Pump_Connected") then
			nozzle.FillBegin:Play()
			task.wait(nozzle.FillBegin.TimeLength)
			nozzle.Fill:Play();
			vehicle:SetAttribute("Car_Fueling", true);
			vehicle:SetAttribute("Car_Running", false);

			local moneySpent = 0;			
			while pump:GetAttribute("Pump_Connected") and vehicle:GetAttribute("Fuel_Current") < vehicle:GetAttribute("Fuel_Max") and pump:GetAttribute("Fuel_Current")>0 do
				local vehicleFuel = vehicle:GetAttribute("Fuel_Current")
				local vehicleMax = vehicle:GetAttribute("Fuel_Max")
				if vehicleFuel < vehicleMax then 
					local refuelStep = pump:GetAttribute("Pump_Amount")/10
					local refuelStored = pump:GetAttribute("Fuel_Current")
					if refuelStored<refuelStep then refuelStep=refuelStored end

					local newFuel = math.clamp(vehicleFuel+ (refuelStep), 0, vehicleMax)
					vehicle:SetAttribute("Fuel_Current", newFuel)
					if pump:GetAttribute("Fuel_Infinite")~=true then
						pump:SetAttribute("Fuel_Current", refuelStored-refuelStep)
					end

					moneySpent += pump:GetAttribute("Pump_Cost") / 10;
					sign.SurfaceGui.Pumped.Text = string.format("$%.2f", moneySpent)
					if vehicleFuel >= vehicleMax then
						sign.SurfaceGui.Pumped.Text = "Fuel tank full"
					end
				end
				task.wait(0.1);
			end
			nozzle.Fill:Stop();
			vehicle:SetAttribute("Car_Fueling", false);
		else
			if pump:GetAttribute("Fuel_Infinite")~=true and pump:GetAttribute("Fuel_Current") <= 0 then
				sign.SurfaceGui.Pumped.Text = "No fuel left"
			elseif pump:GetAttribute("Fuel_Infinite")~=true then
				sign.SurfaceGui.Pumped.Text = math.floor(pump:GetAttribute("Fuel_Current")).." units left"
			end
		end
	end)

	pump:AddTag("INTERACT_LOADED")
end

function mod.SetupRegenPad(regen: Model)
	if not regen:IsDescendantOf(game.Workspace) then return end
	if regen:HasTag("INTERACT_LOADED") then return end
	
	--/ Initialize
	local trigger = regen.Trigger
	local vehicle = assets.VehicleStorage:FindFirstChild(regen:GetAttribute("vehicleName"))

	if not trigger then return end
	if not vehicle then print("Sample vehicle not found!") return end

	local click:ClickDetector = trigger:FindFirstChildWhichIsA("ClickDetector")
	if click then
		if trigger.Vehicle.Value and isOccupied(trigger.Vehicle.Value)==true and not trigger.Vehicle.Value:HasTag("Dragoon_Destroyed") then 
			click:SetAttribute("CursorText", "Can't Regen: Vehicle in use")
		else
			click:SetAttribute("CursorText", "Regen: "..vehicle.Name)
		end

		click.MouseClick:Connect(function(player)
			if player.Character.Humanoid.Sit then return end

			local groupId = regen:GetAttribute("groupId")
			local rankId = regen:GetAttribute("groupRank") or 1
			if groupId and groupId~=0 and rankId and player:GetRankInGroup(groupId)<rankId then notifMod.Notificate(player, false, "LowerMid", 5, "Can't Spawn: Group limited spawn!"); return end

			if trigger.Vehicle.Value and isOccupied(trigger.Vehicle.Value)==true and not trigger.Vehicle.Value:HasTag("Dragoon_Destroyed") then 
				click:SetAttribute("CursorText", "Can't Regen: Vehicle in use")
				wait(2)
				click:SetAttribute("CursorText", "Regen: "..vehicle.Name)
				return
			else
				click:SetAttribute("CursorText", "Regen: "..vehicle.Name)
			end

			if regen:GetAttribute("inUse") then return end
			regen:SetAttribute("inUse", true)

			--UpdateText(regen, vehicle.Name, nil, false)

			local notifMessage
			if trigger.Vehicle.Value and regen:GetAttribute("useInfinite")~=true then 
				notifMessage = [[<font color="#8aff4b">]].."["..trigger.Vehicle.Value:GetAttribute("Vehicle_Name").."] "..[[</font>]].."has been respawned!"
				trigger.Vehicle.Value:Destroy() 
			else
				notifMessage = [[<font color="#8aff4b">]].."["..vehicle:GetAttribute("Vehicle_Name").."] "..[[</font>]].."has been spawned!"
			end

			local currentCar:Model = vehicle:Clone()
			trigger.Vehicle.Value = currentCar
			currentCar:PivotTo(trigger.SpawnPos.WorldCFrame)
			currentCar.Parent = game.Workspace.Vehicles

			if currentCar:HasTag("Okami_Chassis") then
				currentCar:PivotTo(trigger.SpawnPos.WorldCFrame)
				mod.SetupCar(currentCar)
			end

			notifMod.Notificate(player, false, "LowerMid", 5, notifMessage)
			--HandleVehicle(regen, currentCar)
			wait(regen:GetAttribute("useCooldown"))		
			--UpdateText(regen, vehicle.Name, nil, false)
			regen:SetAttribute("inUse", false)
		end)
	end
	local prompt:ProximityPrompt = trigger:FindFirstChildWhichIsA("ProximityPrompt")
	if prompt then
		if trigger.Vehicle.Value and isOccupied(trigger.Vehicle.Value)==true and not trigger.Vehicle.Value:HasTag("Dragoon_Destroyed") then 
			prompt.ActionText = "Can't Regen: Vehicle in use"
		else
			prompt.ActionText = "Regen Vehicle"
		end
		prompt.ObjectText = vehicle.Name

		prompt.Triggered:Connect(function(player)
			if player.Character.Humanoid.Sit then return end

			local groupId = regen:GetAttribute("groupId")
			local rankId = regen:GetAttribute("groupRank") or 1
			if groupId and groupId~=0 and rankId and player:GetRankInGroup(groupId)<rankId then notifMod.Notificate(player, false, "LowerMid", 5, "Can't Spawn: Group limited spawn!"); return end

			if trigger.Vehicle.Value and isOccupied(trigger.Vehicle.Value)==true and not trigger.Vehicle.Value:HasTag("Dragoon_Destroyed") then 
				prompt.ActionText = "Can't Regen: Vehicle in use"
				wait(2)
				prompt.ActionText = "Regen Vehicle"
				return
			else
				prompt.ActionText = "Regen Vehicle"
			end

			if regen:GetAttribute("inUse") then return end
			regen:SetAttribute("inUse", true)

			--UpdateText(regen, vehicle.Name, nil, false)
			local notifMessage
			if trigger.Vehicle.Value and regen:GetAttribute("useInfinite")~=true then
				notifMessage = [[<font color="#8aff4b">]].."["..trigger.Vehicle.Value:GetAttribute("Vehicle_Name").."] "..[[</font>]].."has been respawned!"
				trigger.Vehicle.Value:Destroy() 
			else
				notifMessage = [[<font color="#8aff4b">]].."["..vehicle:GetAttribute("Vehicle_Name").."] "..[[</font>]].."has been spawned!"
			end


			local currentCar:Model = vehicle:Clone()
			trigger.Vehicle.Value = currentCar
			currentCar:PivotTo(trigger.SpawnPos.WorldCFrame)
			currentCar.Parent = game.Workspace.Vehicles

			if currentCar:HasTag("Okami_Chassis") then
				currentCar:PivotTo(trigger.SpawnPos.WorldCFrame)
				mod.SetupCar(currentCar)
			elseif not currentCar:HasTag("Okami_Chassis") and currentCar:HasTag("Dragoon_Vehicle") then
				dtsSetup.LoadVic(currentCar)
			end

			notifMod.Notificate(player, false, "LowerMid", 5, notifMessage)
			--HandleVehicle(regen, currentCar)
			wait(regen:GetAttribute("useCooldown"))		
			--UpdateText(regen, vehicle.Name, nil, false)
			regen:SetAttribute("inUse", false)
		end)
	end
	--if trigger.Vehicle.Value then HandleVehicle(regen, trigger.Vehicle.Value) end
	regen:AddTag("INTERACT_LOADED")
end

return mod
