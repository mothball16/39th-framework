--[[       
INTERACTIVE SYSTEM
Vehicle Spawner Module
1.4.3

based on an old Order of Cobalt script.

by Jarr (@SrJarr) aka jarr__
RELEASED FOR FREE - DRAGOON'S DEN
--]]

--// Services
local players = game:GetService("Players")
local collection = game:GetService("CollectionService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local mod = {}

mod.InitializeWithCoroutine = false
mod.RunWithCoroutine = false
mod.RunTags = 
	{ --tag, function to run
		["Vehicle_Spawner"] = "SetupSpawnMenu",
		["Vehicle_Rearm"] = "SetupRepair"
	}

--// Folders
local assets = replicatedStorage.INTERACT_Assets
local modules = assets.Modules
local vicConfig = require(script.SpawnLimits)
local dtsSetup = replicatedStorage:FindFirstChild("DTS_Assets") and require(replicatedStorage.DTS_Assets.Modules.VehicleSetup)
local okamiSetup = modules:FindFirstChild("OkamiDD") and require(modules.OkamiDD)
local spaceSetup = modules:FindFirstChild("Spaceships") and require(modules.Spaceships)
local notifMod = require(modules.NotifModule)

local vehicleSamples = assets.VehicleStorage
local vehicles = game.Workspace.Vehicles
local gui = script.VicSpawn_UI

local checkParams:OverlapParams = OverlapParams.new()
local vehiclePools = {} --["Tag"] = {vic}

--// Functions
local function GetOccupants(target)
	local occupants = {}
	for _, Seat in target:GetDescendants() do
		if Seat:IsA("Seat") or Seat:IsA("VehicleSeat") then
			if Seat.Occupant then table.insert(occupants, Seat.Occupant) end
		end
	end
	return occupants
end

local function ParentCheckIII(Part:BasePart, ParentTag:string, Times:number)
	local tries = 0
	Times = Times or 6
	local currentPart = Part
	while currentPart and tries < Times do
		if currentPart:HasTag(ParentTag) then return currentPart end
		currentPart = currentPart.Parent
		tries += 1
	end
	return nil
end

local function PlayerAuth(plr:Player, spawner)
	local spawnerConfig = spawner:FindFirstChild("SpawnerSettings") or spawner:FindFirstChild("RearmerSettings")
	if not spawnerConfig then return end
	spawnerConfig = require(spawnerConfig)

	local groupCheck = spawnerConfig.GroupID and plr:GetRankInGroup(spawnerConfig.GroupID)>=spawnerConfig.GroupRank
	local userCheck = table.find(spawnerConfig.Users or {}, plr.Name)~=0
	local teamCheck = table.find(spawnerConfig.Teams or {}, plr.Team.Name)~=0

	return spawnerConfig.FreeUse or teamCheck or userCheck or groupCheck
end

local function PlayerNearby(position:Vector3)
	if vicConfig.Settings.RegenProximity and position then
		local closestDist = vicConfig.Settings.RegenProximity
		for _, player:Player in game.Players:GetPlayers() do
			if not player.Character then continue end
			if not player.Character:FindFirstChild("HumanoidRootPart") then continue end

			local dist = (player.Character.HumanoidRootPart.Position - position).Magnitude
			closestDist = (dist<closestDist and dist) or closestDist
			
			if dist<vicConfig.Settings.RegenProximity then
				print("VehicleSpawner: Couldn't despawn a vehicle because a player was near it")
			end
		end
		return closestDist < vicConfig.Settings.RegenProximity
	else
		return false
	end
end

local function CleanVics(original:Model?, target: string?)
	local count = 0
	for each, vic:Model in vehicles:GetChildren() do
		local regenProof = vic:HasTag("INTERACT_RegenProof")
		if regenProof then continue end

		local occupants = GetOccupants(vic)
		if #occupants~=0 then continue end

		if original and vic==original then continue end
		if target and vic.Name~=target then continue end
		if PlayerNearby(vic:GetPivot().Position) then continue end

		count += 1
		vic:Destroy()
	end
	return count
end

local function CleanArea(spawnerData: Model, plr:Player, checkResults:{BasePart})
	local foundVic:Model?

	--Check each basepart for a tag
	for _, part:BasePart in checkResults do
		if not part:IsA("BasePart") then continue end

		for _, tag in vicConfig.Settings.ClearTags do
			foundVic = ParentCheckIII(part, tag, 3)
			if foundVic then break end
		end
		if foundVic then break end
	end

	--Delete the vehicle found, only if there are no people inside
	local occupants = foundVic and GetOccupants(foundVic)
	if foundVic and #occupants == 0 and not foundVic:HasTag("INTERACT_RegenProof") then
		foundVic:Destroy() 
	elseif foundVic and #occupants ~= 0 then 
		notifMod.Notificate(plr, false, "LowerMid", 5, " A player's vehicle is blocking the spawner! ")
	elseif foundVic and foundVic:HasTag("INTERACT_RegenProof") then 
		notifMod.Notificate(plr, false, "LowerMid", 5, " A vehicle is blocking the spawner, but we cannot remove it! ")
	end
end

local function GroupVicsByPool()
	--First, create an array for each one of the tags in the spawn pools
	for tag, amount in vicConfig.SpawnPools do
		vehiclePools[tag] = {}
	end

	--Then, check every vehicle and group them by their tag
	for modelName, modelData in vicConfig.Info do
		local pool = vehiclePools[modelData.SpawnLimit]
		if not pool then continue end
		table.insert(pool, modelName)
	end
end

local function CountSingleVics(Target: string)
	local count = 0
	for each, vic in vehicles:GetChildren() do
		if vic.Name == Target then count+=1 end
	end
	return count
end

local function CountMultipleVics(vehicleName:string)
	local vehicleEntry = vicConfig.Info[vehicleName]
	local vehicleTag = vehicleEntry and vehicleEntry.SpawnLimit
	if not vehicleEntry then error("VehicleSpawner: Vehicle Entry not found for:"..(vehicleName or "NoName")) return end

	if type(vehicleTag)=="string" then
		local pool = vehiclePools[vehicleTag]
		if not pool then warn("VehicleSpawner: Spawn pool specified but not found.") return end

		local count = 0
		for each, poolVic in pool do
			count += CountSingleVics(poolVic)
		end
		return count
	else
		return CountSingleVics(vehicleName)
	end
end

local function GetVehicleLimits(vehicleName:string)
	local vehicleEntry = vicConfig.Info[vehicleName]
	local vehicleTag = vehicleEntry and vehicleEntry.SpawnLimit
	if not vehicleEntry then error("VehicleSpawner: Vehicle Entry not found for:"..(vehicleName or "NoName")) return end

	if type(vehicleTag)=="string" then
		return vicConfig.SpawnPools[vehicleTag]
	elseif type(vehicleTag)=="number" then
		return vehicleTag
	else
		return 99
	end
end

local function TeleportPlayer(vehicle:Model, player:Player)
	if not vehicle or not player or not player.Character then return end
	
	local functional = vehicle:FindFirstChild("Functional")
	local aircraft = vehicle:FindFirstChild("Aircraft")
	local seats = functional and functional:FindFirstChild("Seats")
	local seats2 = vehicle:FindFirstChild("Decorative")
	local seats3 = aircraft and aircraft:FindFirstChild("Main")
	
	local finalSeat:Seat?
	if seats then
		for _, seat:VehicleSeat in seats:GetChildren() do
			if finalSeat then continue end
			if not seat:IsA("Seat") and not seat:IsA("VehicleSeat") then continue end
			finalSeat = seat
		end
	end
	if seats2 and not finalSeat then
		for _, seat:VehicleSeat in seats2:GetChildren() do
			if finalSeat then continue end
			if not seat:IsA("Seat") and not seat:IsA("VehicleSeat") then continue end
			finalSeat = seat
		end
	end
	if seats3 and not finalSeat then
		for _, seat:VehicleSeat in seats3:GetChildren() do
			if finalSeat then continue end
			if not seat:IsA("Seat") and not seat:IsA("VehicleSeat") then continue end
			finalSeat = seat
		end
	end
	
	if finalSeat then
		local human = player.Character:FindFirstChildWhichIsA("Humanoid")
		--player.Character:PivotTo(finalSeat.CFrame)
		finalSeat:Sit(human)
	end
end

local function SetupVic(vehicle:Model, position:CFrame, player:Player)
	--Team
	vehicle:SetAttribute("Vehicle_Team", (player and player.Team and player.Team.Name) or "Default")
	
	--Setup
	if vehicle:HasTag("Okami_Chassis") and okamiSetup then
		vehicle:PivotTo(position)
		okamiSetup.SetupCar(vehicle)
	elseif vehicle:HasTag("Dragoon_Spaceship") and spaceSetup then
		spaceSetup.SetupSpaceship(vehicle)
	elseif vehicle:HasTag("Okami_Trailer") and okamiSetup then
		okamiSetup.initializeTrailer(vehicle)
	elseif dtsSetup and not vehicle:HasTag("Okami_Chassis") and not vehicle:HasTag("Dragoon_Spaceship") and vehicle:HasTag("Dragoon_Vehicle") then
		dtsSetup.LoadVic(vehicle)
	end

	for each, thing in vehicle:GetChildren() do
		if thing:HasTag("Vehicle_Spawner") then
			mod.SetupSpawnMenu(thing)
		end
	end
	
	task.delay(0.5, function()
		--Teleport
		if player and vicConfig.Settings.TeleportPlayer then
			print("Teleporting!")
			TeleportPlayer(vehicle, player)
		end
	end)
end

local function ServiceVic(vehicle:Model, spawnerData: {Position:Vector3, Size:Vector3, Object:Model}, player:Player)
	if not vehicle then warn("VehicleSpawner: Nothing to repair!") return end

	local spawnerModule = spawnerData.Object:FindFirstChild("RearmerSettings")
	local spawnerConfig = spawnerModule and require(spawnerModule)
	if not spawnerConfig then return end

	--Health
	if spawnerConfig.Repair then
		print("Repair!")
		local maxHP = vehicle:GetAttribute("Vehicle_MaxHP")
		local nowHP = vehicle:GetAttribute("Vehicle_HP")

		if nowHP and maxHP and nowHP<maxHP then 
			vehicle:SetAttribute("Vehicle_HP", maxHP)

			local notifMessage = [[<font color="#8aff4b"> ]].."["..vehicle:GetAttribute("Vehicle_Name").."] "..[[</font>]].." Repaired! "
			notifMod.Notificate(player, false, "LowerMid", 3, notifMessage)

			spawnerData.Object.Trigger.Repair:Play()
			task.wait(1)
		end
	end

	--Fuel
	local fuelType = vehicle:GetAttribute("Fuel_Type") or "Default"
	local fuelMatch = spawnerConfig.RefuelType==nil or (fuelType and spawnerConfig.RefuelType==fuelType)
	if spawnerConfig.Refuel and fuelMatch then
		print("Refuel!")
		local maxFuel = vehicle:GetAttribute("Fuel_Max")
		local nowFuel = vehicle:GetAttribute("Fuel_Current")
		if nowFuel and maxFuel and nowFuel<maxFuel then
			vehicle:SetAttribute("Fuel_Current", maxFuel)

			local notifMessage = [[<font color="#8aff4b"> ]].."["..vehicle:GetAttribute("Vehicle_Name").."] "..[[</font>]].." Refueled! "
			notifMod.Notificate(player, false, "LowerMid", 3, notifMessage)

			spawnerData.Object.Trigger.Refuel:Play()
			task.wait(1)
		end
	end

	--Rearm
	if spawnerConfig.Rearm then
		print("Rearm!")
		local weapons = vehicle:FindFirstChild("Weapons")
		local addons = vehicle:FindFirstChild("Addons")
		if not weapons or not addons then return end
		weapons = weapons:GetChildren()
		addons = addons:GetChildren()

		for _, weapon in weapons do
			local module = weapon:FindFirstChildOfClass("ModuleScript")
			if not module then continue end

			local moduleCFG = require(module)
			if moduleCFG.MaxAmmo and moduleCFG.ClipSize then
				weapon:SetAttribute("clipAmmo", moduleCFG.ClipSize)
				weapon:SetAttribute("storedAmmo", moduleCFG.MaxAmmo)
				weapon:SetAttribute("maxAmmo", moduleCFG.MaxAmmo)

				local notifMessage = [[<font color="#8aff4b"> ]].."["..weapon:GetAttribute("Weapon_Name").."] "..[[</font>]].." Rearmed! "
				notifMod.Notificate(player, false, "LowerMid", 3, notifMessage)

				spawnerData.Object.Trigger.Rearm:Play()
				task.wait(1/#weapons)
			end
		end

		for _, weapon in addons do
			local module = weapon:FindFirstChildOfClass("ModuleScript")
			if not module then continue end

			local moduleCFG = require(module)
			local clipAmmo = weapon:GetAttribute("clipAmmo")
			local storedAmmo = weapon:GetAttribute("storedAmmo")
			local maxAmmo = weapon:GetAttribute("maxAmmo")

			if moduleCFG.MaxAmmo and moduleCFG.ClipSize and clipAmmo<maxAmmo or storedAmmo<maxAmmo then
				weapon:SetAttribute("clipAmmo", moduleCFG.ClipSize)
				weapon:SetAttribute("storedAmmo", moduleCFG.MaxAmmo)
				weapon:SetAttribute("maxAmmo", moduleCFG.MaxAmmo)

				local notifMessage = [[<font color="#8aff4b"> ]].."["..weapon:GetAttribute("Addon_Name").."] "..[[</font>]].." Rearmed! "
				notifMod.Notificate(player, false, "LowerMid", 3, notifMessage)

				spawnerData.Object.Trigger.Rearm:Play()
				task.wait(1/#weapons)
			end
		end
	end
end

local function RepairVic(spawnerData: {Position:Vector3, Size:Vector3, Object:Model}, plr:Player)
	local checkPos:Attachment = spawnerData.Position 
	local checkSize:Vector3Value = spawnerData.Size

	--Area check exclusivity
	checkParams.FilterType = (vicConfig.Settings.CollisionExclusive and Enum.RaycastFilterType.Include) or Enum.RaycastFilterType.Exclude
	checkParams.FilterDescendantsInstances = (vicConfig.Settings.CollisionExclusive and {vehicles}) or {spawnerData.Object}

	local checkResults = workspace:GetPartBoundsInBox(checkPos.WorldCFrame, checkSize.Value, checkParams)
	if not checkResults or #checkResults <= 0 then return end

	--Check each basepart for a tag
	local foundVic:Model?
	for _, part:BasePart in checkResults do
		if not part:IsA("BasePart") then continue end

		for _, tag in vicConfig.Settings.ClearTags do
			foundVic = ParentCheckIII(part, tag, 3)
			if foundVic then break end
		end
		if foundVic then break end
	end
	ServiceVic(foundVic, spawnerData, plr)
end

local function SpawnVic(vehicle: Model, spawnerData: {Position:Vector3, Size:Vector3, Object:Model}, plr:Player, debounce:boolean?)
	local vehicleEntry = vicConfig.Info[vehicle.Name]
	if not vehicleEntry then warn("VehicleSpawner: No entry for this vehicle we're about to spawn??") end

	local checkPos:CFrame = spawnerData.Position 
	local checkSize:Vector3Value = spawnerData.Size

	--Area check exclusivity
	checkParams.FilterType = (vicConfig.Settings.CollisionExclusive and Enum.RaycastFilterType.Include) or Enum.RaycastFilterType.Exclude
	checkParams.FilterDescendantsInstances = (vicConfig.Settings.CollisionExclusive and {vehicles}) or {spawnerData.Object}

	local checkResults = workspace:GetPartBoundsInBox(checkPos, checkSize, checkParams)
	local checkCooldown = vehicle:FindFirstChild("RespawnTimer")

	if #checkResults == 0 or not vicConfig.Settings.CollisionCheck and not checkCooldown then
		if vehicleEntry and vehicleEntry.SpawnCooldown then
			local coolTag = Instance.new("NumberValue")
			coolTag.Name = "RespawnTimer"
			coolTag.Value = os.clock()
			coolTag:SetAttribute("Duration", vehicleEntry.SpawnCooldown)
			coolTag.Parent = vehicle
			game.Debris:AddItem(coolTag, vehicleEntry.SpawnCooldown)
		end

		local newVic = vehicle:Clone()
		newVic:PivotTo(checkPos)
		newVic.Parent = vehicles
		SetupVic(newVic, checkPos, plr)

		if vicConfig and vicConfig.Settings.RegenProof and not newVic:HasTag("INTERACT_RegenProof")  then
			--vic:HasTag("INTERACT_RegenProof")
			newVic:AddTag("INTERACT_RegenProof") 
			task.delay(vicConfig.Settings.RegenProof, function()
				newVic:RemoveTag("INTERACT_RegenProof")
			end)
		end

		local notifMessage = [[<font color="#8aff4b"> ]].."["..(newVic:GetAttribute("Vehicle_Name") or newVic.Name).."] "..[[</font>]].."has been spawned!"
		notifMod.Notificate(plr, false, "LowerMid", 5, notifMessage)

		return true --success!!
	elseif vicConfig.Settings.ClearArea and vicConfig.Settings.CollisionCheck and #checkResults~=0 and not debounce and not checkCooldown then
		CleanArea(spawnerData, plr, checkResults)
		return SpawnVic(vehicle, spawnerData, plr, true)
	elseif checkCooldown then
		local deltaTime = checkCooldown:GetAttribute("Duration") - math.ceil(os.clock() - checkCooldown.Value)
		notifMod.Notificate(plr, false, "LowerMid", 5, " This vehicle is under cooldown. Remaining time: "..deltaTime.." seconds! ")
		return false
	else
		notifMod.Notificate(plr, false, "LowerMid", 5, " Something is blocking the spawner! ")
		print("VehicleSpawner: Something is blocking the spawner!")
		return false
	end
end

local function AutoClean()
	local cleanTime = vicConfig.Settings.AutoClean
	if cleanTime then
		task.spawn(function()
			while true do
				task.wait(cleanTime)
				local count = CleanVics(nil, nil)
				print("VehicleSpawner: Automatic Cleanup performed. "..count.." vehicles removed!")
			end
		end)
	end
end

--// Core Functions
local function ServerInvoke(plr:Player, func, ...)
	local vars = {...}

	if func=="Count" then
		local count = CountMultipleVics(vars[1])
		local max = GetVehicleLimits(vars[1])
		--print("CountFunc", count, max)
		return {count, max}
	elseif func=="Exit" then
		local SpawnerUI = plr.PlayerGui:FindFirstChild(gui.Name)
		if SpawnerUI then SpawnerUI:Destroy() end
	elseif func=="Spawn" then
		local vehicle = vars[1]
		local spawnerData = vars[2]
		local foundVics = CountMultipleVics(vehicle.Name)
		local foundLimit = GetVehicleLimits(vehicle.Name)
		local checkCooldown = vehicle:FindFirstChild("RespawnTimer")
		if checkCooldown then return false end

		if foundLimit and foundLimit > 0  then
			if foundVics < foundLimit then
				return SpawnVic(vehicle, spawnerData, plr)
			elseif foundVics >= foundLimit then
				CleanVics(nil, vehicle.Name)
				return false
			end
		elseif foundLimit and foundLimit == -1 then
			local newVic = SpawnVic(vehicle, spawnerData, plr)
			CleanVics(newVic, newVic.Name)
			return newVic
		end
	end
end

function mod.Initialize()
	assets.Events.VehicleSpawn.OnServerInvoke = ServerInvoke
	GroupVicsByPool()
	AutoClean()
end

function mod.SetupSpawnMenu(rootModel: Model)
	if rootModel:IsDescendantOf(replicatedStorage) then return end
	if rootModel:HasTag("INTERACT_LOADED") then return end

	--/ Initialize
	local Trigger = rootModel:FindFirstChild("Trigger")
	if not Trigger then return end

	local prompt = Trigger:FindFirstChildWhichIsA("ProximityPrompt")
	if prompt then
		prompt.Triggered:Connect(function(plr)
			if not PlayerAuth(plr, rootModel) then return end

			local foundUI = plr.PlayerGui:FindFirstChild(gui.Name)
			if foundUI then return end

			local newUI = gui:Clone()
			newUI.Parent = plr.PlayerGui
			newUI.VicSpawn_Local.SpawnPos.Value = rootModel.Trigger.SpawnPos.WorldCFrame
			newUI.VicSpawn_Local.SpawnSize.Value = rootModel.Trigger.SpawnSize.Value
			newUI.VicSpawn_Local.SpawnerSettings.Value = rootModel.SpawnerSettings
			newUI.VicSpawn_Local.Spawner.Value = rootModel
			newUI.VicSpawn_Local.Enabled = true
		end)
	end

	rootModel:AddTag("INTERACT_LOADED")
end

function mod.SetupSpawnMenu2(plr, SpawnPos, SpawnSize, SpawnSettings)
	local foundUI = plr.PlayerGui:FindFirstChild(gui.Name)
	if foundUI then return foundUI end

	local newUI = gui:Clone()
	newUI.Parent = plr.PlayerGui
	newUI.VicSpawn_Local.SpawnPos.Value = SpawnPos
	newUI.VicSpawn_Local.SpawnSize.Value = SpawnSize
	newUI.VicSpawn_Local.SpawnerSettings.Value = SpawnSettings
	newUI.VicSpawn_Local.Enabled = true
	return newUI
end

function mod.SetupRepair(rootModel: Model)
	if rootModel:IsDescendantOf(replicatedStorage) then return end
	if rootModel:HasTag("INTERACT_LOADED") then return end

	--/ Initialize
	local Trigger = rootModel:FindFirstChild("Trigger")
	if not Trigger then return end

	local prompt = Trigger:FindFirstChildWhichIsA("ProximityPrompt")
	if prompt then
		prompt.Triggered:Connect(function(plr)
			if not PlayerAuth(plr, rootModel) then return end

			RepairVic(rootModel, plr)
		end)
	end

	rootModel:AddTag("INTERACT_LOADED")
end

return mod
