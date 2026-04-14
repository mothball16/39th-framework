--[[       
DRAGOON TANK SYSTEM
Spotting System
1.2.0
--]]

local module = {}

--// Services
local replicatedStorage = game:GetService("ReplicatedStorage")
local collection = game:GetService("CollectionService")
local userInput = game:GetService("UserInputService")
local debris = game:GetService("Debris")
local players = game:GetService("Players")
local guiservice = game:GetService("GuiService")

local player = game.Players.LocalPlayer
local playerCam = game.Workspace.CurrentCamera

--// Folders
local assets = replicatedStorage.DTS_Assets
local modules = assets.Modules
local workspaceFolder = game.Workspace.DTS_Workspace

local hudMod = require(modules.HUDModule)
local config = require(assets.GlobalSettings)
local notifMod = require(replicatedStorage.INTERACT_Assets.Modules.NotifModule) --Interact system shared module

local sphInstall = replicatedStorage:FindFirstChild("SPH_Assets") --Spearhead compat
local bridgeNet
if sphInstall then 
	bridgeNet = require(sphInstall.Modules.Network.BridgeNet)
else  
	bridgeNet = require(modules.BridgeNet) 
end

local addonEvent = bridgeNet.CreateBridge("AddonEvent")

local aimingParams = RaycastParams.new()
aimingParams.FilterType = Enum.RaycastFilterType.Exclude
aimingParams.IgnoreWater = true

local cooldown = false
local lastSpotPos:Vector3?
local lastSpotObj:Instance?

--// Functions
local function trim(str)
	return str:match("^%s*(.-)%s*$")
end

local function StringToVector3(str:string?)
	--Handle nil or empty string
	if not str or trim(str) == "" then
		return nil
	end

	--Remove all brackets/parentheses/commas if present, replace with spaces
	str = str:gsub("[%(%)%[%]{}]", "")
	str = str:gsub(",", " ")

	--Extract all numbers (including negatives and decimals)
	local numbers = {}
	for num in str:gmatch("-?%d+%.?%d*") do
		table.insert(numbers, tonumber(num))
	end

	--Return nil if we didn't find exactly 3 numbers
	if #numbers ~= 3 then return nil end

	--Create and return the Vector3
	return Vector3.new(numbers[1], numbers[2], numbers[3])
end

local function GetTarget(vehicle, rangeMax, guiw, autoMode)
	local newSpotPos
	local newSpotObj
	
	if autoMode then
		local targetPos:Vector3Value = player:FindFirstChild("Target_Pos") 
		local targetObj:ObjectValue = player:FindFirstChild("Target_Obj")
		if not targetPos or not targetObj then return end

		local finalPos = targetObj.Value and targetObj.Value:GetPivot().Position or targetPos.Value
		newSpotPos = finalPos
		newSpotObj = targetObj.Value
	else
		local mouseXY = userInput:GetMouseLocation()
		local mouseRay:Ray = playerCam:ViewportPointToRay(mouseXY.X, mouseXY.Y, 0)

		aimingParams.FilterDescendantsInstances = {player.Character, vehicle}
		local aimingCast = workspace:Raycast(mouseRay.Origin, mouseRay.Direction*rangeMax, aimingParams)
		if aimingCast and aimingCast.Position then
			newSpotPos = aimingCast.Position
		end
	end
	return newSpotPos, newSpotObj
end

local function Spot(vehicle:Model, addonObj:Folder, gun:Model, addonConfig, guiw, autoMode)
	local spotPos, spotObj = GetTarget(vehicle, addonConfig.MaxRange*3.5, guiw, autoMode)
	if not spotPos and not spotObj then return end

	guiw.Spot:Play()
	lastSpotPos = spotPos
	lastSpotObj = spotObj
	addonEvent:Fire(script.Name, "ShareTarget", player, vehicle, spotPos, spotObj, addonConfig.Duration, addonConfig.DatalinkCapable, addonConfig.SeatWhitelist)
end

--// Core Functions
function module.ShareTarget(player:Player, vehicle:Model, spotPos:Vector3, spotObj:Instance?, duration:number, datalinkCapable:boolean, seatWhitelist:{})
	if not player or not player.Character or not vehicle or not spotPos then return end
	
	local occupants = {}
	for _, part in vehicle:GetDescendants() do
		if not part:IsA("Seat") and not part:IsA("VehicleSeat") then continue end
		if not part.Occupant then continue end
		if seatWhitelist and type(seatWhitelist)=="table" and #seatWhitelist>0 and table.find(seatWhitelist, part.Name)==nil then continue end
		table.insert(occupants, part.Occupant)
	end
	if #occupants <= 0 or not table.find(occupants, player.Character:FindFirstChildWhichIsA("Humanoid")) then return end
	
	local pingColor = Color3.fromRGB(math.random(1, 25)*10, math.random(1, 25)*10, math.random(1, 25)*10)
	local pingId = (replicatedStorage.INTERACT_Assets.Modules.NotifModule:GetAttribute("Ping_Counter") or 1)
	replicatedStorage.INTERACT_Assets.Modules.NotifModule:SetAttribute("Ping_Counter", (pingId<notifMod.MaxPings and pingId+1) or 1)
	
	for _, human:Humanoid in occupants do
		if human.Health <= 0 then continue end
		local otherPlayer = players:GetPlayerFromCharacter(human.Parent)
		if not otherPlayer then continue end
		
		notifMod.PingLocation(otherPlayer, player.UserId, spotPos, spotObj, duration or 5, nil, pingColor, pingId, datalinkCapable)
	end
end

function module.InputBegan(inputObj:InputObject, weaponActive, vehicle, addonObj, gun, addonConfig, guiw)
	if table.find(addonConfig.AddonCodeFiring, weaponActive)==nil then return end

	if inputObj.KeyCode == addonConfig.AutoKeybind and addonConfig.AutoSpot and not cooldown then
		Spot(vehicle, addonObj, gun, addonConfig, guiw, true)
		cooldown = true
		task.delay(addonConfig.Cooldown, function()
			cooldown = false
		end)
	elseif inputObj.KeyCode == addonConfig.ManualKeybind and addonConfig.ManualSpot and not cooldown then
		Spot(vehicle, addonObj, gun, addonConfig, guiw, false)
		cooldown = true
		task.delay(addonConfig.Cooldown, function()
			cooldown = false
		end)
	end
end

function module.RenderLoop(dt, weaponActive, vehicle, addonObj, gun, addonConfig, wpnGui, cameraMode, mouseDelta) --Runs on renderstepped
	local aiming = table.find(addonConfig.AddonCodeAiming, weaponActive)~=nil
	wpnGui.Visible = aiming

	if not aiming or not addonConfig.TurretInstalled then return end 

	--Update the UI
	local dist = lastSpotPos and (playerCam.CFrame.Position - lastSpotPos).Magnitude
	hudMod.UpdateSights(addonObj, wpnGui, cameraMode>=1, lastSpotPos, playerCam.CFrame.Position, playerCam.CFrame, playerCam.CFrame, dist, mouseDelta, dt, addonConfig)

	if lastSpotPos and lastSpotPos~=Vector3.zero then
		return lastSpotPos --If the spotting system happens to have a turret, it will aim to the last spotted location
	end
end

function module.WeaponSwitch(oldWeapon, newWeapon, vehicle, addonObj, gun, addonConfig, wpnGui)
	cooldown = false
end

--[[ 
function module.LoadModule(addonObj:Folder, vehicle, guiw)
	local wepStats = require(addonObj:FindFirstChildWhichIsA("ModuleScript"))
end

function module.WeaponSwitch(oldWeapon, newWeapon, vehicle, addonObj, gun, addonConfig, wpnGui)
	local firing = table.find(addonConfig.AddonCodeFiring, newWeapon)~=nil
end

function module.RunLoop(dt, weaponActive, vehicle, addonObj, gun, addonConfig, wpnGui, wpnConfig) --Runs on heartbeat
	if not table.find(addonConfig.AddonCodeFiring, weaponActive) then return end
end
-]]

return module