--[[       
DRAGOON TANK SYSTEM
Targeting System
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

local tgtMod = require(replicatedStorage.INTERACT_Assets.Modules.TargetingSystem)
local hudMod = require(modules.HUDModule)
local config = require(assets.GlobalSettings)

local sphInstall = replicatedStorage:FindFirstChild("SPH_Assets") --Spearhead compat
local bridgeNet
if sphInstall then 
	bridgeNet = require(sphInstall.Modules.Network.BridgeNet)
else  
	bridgeNet = require(modules.BridgeNet) 
end

local addonEvent = bridgeNet.CreateBridge("AddonEvent")

local raycastParams =  RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true

local uiElements = {"Frame", "TextLabel", "ImageLabel", "ScrollingFrame"}

local markedDist:number = 999999
local markedTarget:Model?
local markedPos:number
local markedTime
local markedState = 0 --0: nothing, 1: locking, 2: fully locked

local characters = {} --Store characters so they dont block the radar
local velocityHistory = {}
local velocityHistoryLength = 5 -- number of frames to average

local lastPos
local laserToggle = false

--// Functions
local function LaserPosition(vehicle:Model, maxDistance:number):Vector3?
	--Get camera CFrame and direction
	local cameraCFrame = playerCam.CFrame
	local cameraDir = cameraCFrame.LookVector

	--Perform the raycast
	raycastParams.FilterDescendantsInstances = {vehicle}
	local raycastResult = workspace:Raycast(cameraCFrame.Position, cameraDir * maxDistance, raycastParams)
	return (raycastResult and raycastResult.Position) or cameraCFrame.Position + (cameraDir * maxDistance)
end

local function UpdateMarkers(addonObj, wpnGui, addonConfig)
	for each, uiObj in wpnGui:GetDescendants() do
		if table.find(uiElements, uiObj.ClassName)==nil then continue end --Skip invalid elements
		if uiObj.Parent and uiObj.Parent.Visible == false then continue end --Skip elements we cant see

		if uiObj.Name== "Target_Laser" then
			if markedPos and markedPos~=Vector3.zero and not markedTarget then
				local uiPos, uiVis = playerCam:WorldToViewportPoint(markedPos) --cannon LOS
				uiObj.Position = UDim2.new(0, uiPos.X, 0, uiPos.Y)
				uiObj.Visible = uiVis
			else
				uiObj.Visible = false
			end
		elseif uiObj.Name== "Target_Radar" then
			if markedTarget then
				local uiPos, uiVis = playerCam:WorldToViewportPoint(markedTarget:GetPivot().Position) --cannon LOS
				uiObj.Position = UDim2.new(0, uiPos.X, 0, uiPos.Y)
				uiObj.Visible = uiVis

			else
				uiObj.Visible = false
			end
			uiObj.TextLabel.Text = (markedState==2 and "LOCKED") or "TARGET"
			uiObj.TextLabel.TextColor3 = (markedState==2 and addonConfig.RadarColor[2]) or addonConfig.RadarColor[1]
			uiObj.UIStroke.Color = (markedState==2 and addonConfig.RadarColor[2]) or addonConfig.RadarColor[1]
		end
	end
end

--// Core Functions
function module.ClearTargetData(player:Player)
	tgtMod.ClearTargetData(player, true, true)
end

function module.SetTargetData(player:Player, newPos:Vector3?, newObj:Instance?)
	tgtMod.SetTargetData(player, newPos, newObj)
end

function module.InputBegan(inputObj:InputObject, weaponActive, vehicle, addonObj, gun, addonConfig, guiw)
	if table.find(addonConfig.AddonCodeFiring, weaponActive)==nil then return end
	
	if addonConfig.LaserKeybind and inputObj.KeyCode == addonConfig.LaserKeybind and addonConfig.LaserTargeting then
		if addonConfig.LaserConstant then
			laserToggle = not laserToggle
			guiw.LockLaser:Play()

			if not laserToggle then
				markedDist = 999999
				markedTarget = nil
				markedPos = nil
				markedTime = nil
				markedState = 0
				addonEvent:Fire(script.Name, "ClearTargetData", player)
			end
			return
		end

		local laserPos = LaserPosition(vehicle, addonConfig.LaserRange)
		if laserPos then
			guiw.LockLaser:Play()

			markedPos = laserPos
			addonEvent:Fire(script.Name, "SetTargetData", player, markedPos, nil)
		end
	elseif addonConfig.RadarUnlockKeybind and inputObj.KeyCode == addonConfig.RadarUnlockKeybind and addonConfig.RadarTargeting then
		guiw.LockLaser:Play()
		markedDist = 999999
		markedTarget = nil
		markedPos = nil
		markedTime = nil
		markedState = 0
		addonEvent:Fire(script.Name, "ClearTargetData", player)
	end
end

function module.LoadModule(addonObj:Folder, vehicle, guiw)
	local wepStats = require(addonObj:FindFirstChildWhichIsA("ModuleScript"))

	addonEvent:Fire(script.Name, "ClearTargetData", player)

	local manualInput = guiw:FindFirstChild("Target_ManualInput")
	if manualInput then
		manualInput.Visible = wepStats.ManualInput or false

		if wepStats.ManualInput then
			local textBox:TextBox = manualInput.TargetInput
			textBox.FocusLost:Connect(function(enterPressed)
				markedPos = tgtMod.StringToVector(textBox.Text)
				if markedPos then
					guiw.LockKeyboard:Play()
					addonEvent:Fire(script.Name, "SetTargetData", player, markedPos, nil)
				end
			end)
		end
	end
	
	--Keep a updated list of characters to prevent them from obscuring the radar!
end

function module.WeaponSwitch(oldWeapon, newWeapon, vehicle, addonObj, gun, addonConfig, wpnGui)
	local firing = table.find(addonConfig.AddonCodeFiring, newWeapon)~=nil
	if not firing then
		addonEvent:Fire(script.Name, "ClearTargetData", player)
		local lockingSound = wpnGui.LockIn
		local lockedSound = wpnGui.LockReady
		if lockedSound then lockedSound:Stop() end
		if lockingSound then lockingSound:Stop() end
	end
end

local function CheckTag(object, vehicle, addonConfig)
	if not object:IsA("Model") or not object:IsDescendantOf(game.Workspace) or object==vehicle or markedTarget==object then return end

	local objectHP = object:GetAttribute("Vehicle_HP")
	if object:HasTag("Dragoon_Destroyed") or (objectHP and objectHP<=0) then return end

	local objectPos =  (object.PrimaryPart and object.PrimaryPart.Position) or object:GetPivot().Position
	if objectPos == markedPos then return end

	if tgtMod.TablesShareElement(object:GetTags(), addonConfig.RadarCounter) then return end
	if not tgtMod.IsTargetInFov(addonConfig.RadarFOV, playerCam.CFrame, objectPos, 10) then return end
	if not tgtMod.LineOfSight(vehicle, object, tgtMod.RaycastFilter) then return end

	local dist = (playerCam.CFrame.Position - objectPos).Magnitude
	if dist>addonConfig.RadarRange then return end

	local uiDist = tgtMod.GetUIDistance(objectPos, tgtMod.ScreenCenter)
	if uiDist and uiDist<markedDist then					
		markedDist = uiDist
		markedTarget = object
		markedPos = objectPos
		markedTime = os.clock()
		markedState = 1
	end
end

function module.RenderLoop(dt, weaponActive, vehicle, addonObj, gun, addonConfig, wpnGui, cameraMode, mouseDelta) --Runs on renderstepped
	local firing = table.find(addonConfig.AddonCodeAiming, weaponActive)~=nil
	wpnGui.Visible = firing

	if not firing then return end 

	--Update the UI
	local dist = markedPos and (playerCam.CFrame.Position - markedPos).Magnitude

	hudMod.UpdateSights(addonObj, wpnGui, cameraMode>=1, markedPos, playerCam.CFrame.Position, playerCam.CFrame, playerCam.CFrame, dist, mouseDelta, dt, addonConfig)

	--Update targeting spsecific UI elements
	UpdateMarkers(addonObj, wpnGui, addonConfig)

	--Update the sounds
	local lockingSound = wpnGui.LockIn
	local lockedSound = wpnGui.LockReady

	if markedState~=1 and lockingSound.Playing then
		lockingSound:Stop()
	elseif markedState==1 and not lockingSound.Playing then
		lockingSound:Play()
	end

	if markedState~=2 and lockedSound.Playing then
		lockedSound:Stop()
	elseif markedState ==2 and not lockedSound.Playing  then
		lockedSound:Play()
	end

	if markedPos and markedPos~=Vector3.zero then
		return markedPos
	end
end

function module.RunLoop(dt, weaponActive, vehicle, addonObj, gun, addonConfig, wpnGui, wpnConfig) --Runs on heartbeat
	if not table.find(addonConfig.AddonCodeFiring, weaponActive) then return end

	if addonConfig.LaserTargeting and not addonConfig.RadarTargeting  and addonConfig.LaserConstant and laserToggle then
		local laserPos = LaserPosition(vehicle, addonConfig.LaserRange)
		if laserPos then
			local markedVel = lastPos and (laserPos - lastPos) / dt
			local predictPos
			lastPos = markedPos

			velocityHistory, predictPos = tgtMod.LeadPosition(velocityHistory, playerCam.CFrame.Position, lastPos, laserPos, markedVel, wpnConfig.ShellVelocity*3.5)

			markedPos = (addonConfig.TargetLeading and markedVel and wpnConfig and predictPos) or laserPos
			addonEvent:Fire(script.Name, "SetTargetData", player, markedPos, nil)
		end
	elseif addonConfig.RadarTargeting then
		--Prepare radar
		characters = tgtMod.GetCharacters()
		
		--Search for a target
		for _, tag in addonConfig.RadarTags do
			for _, object:Model in collection:GetTagged(tag) do
				CheckTag(object	, vehicle, addonConfig)
			end
		end

		--Confirm the marked target is still valid
		if markedTarget then
			local objectPos = (markedTarget.PrimaryPart and markedTarget.PrimaryPart.Position) or markedTarget:GetPivot().Position
			local inFov = tgtMod.IsTargetInFov(addonConfig.RadarFOV, playerCam.CFrame, objectPos, 10)
			local inRange = (playerCam.CFrame.Position - objectPos).Magnitude <= addonConfig.RadarRange
			local inSight = inFov and inRange and tgtMod.LineOfSight(vehicle, markedTarget, tgtMod.RaycastFilter) 

			local objectHP = markedTarget:GetAttribute("Vehicle_HP")
			local objectCounter = tgtMod.TablesShareElement(markedTarget:GetTags(), addonConfig.RadarCounter) 
			local objectDead = markedTarget:HasTag("Dragoon_Destroyed") or (objectHP and objectHP<=0)

			if not inFov or not inSight or not inRange or objectCounter or objectDead then
				markedDist = 999999
				markedTarget = nil
				markedPos = nil
				markedTime = nil
				markedState = 0
				addonEvent:Fire(script.Name, "ClearTargetData", player)
				return
			end

			if addonConfig.TargetLeading and wpnConfig then
				local markedVel = lastPos and (objectPos - lastPos) / dt
				local predictPos
				velocityHistory, predictPos = tgtMod.LeadPosition(velocityHistory, playerCam.CFrame.Position, lastPos, objectPos, markedVel, wpnConfig.ShellVelocity*3.5)
				
				lastPos = objectPos
				markedPos = predictPos or objectPos
			end
		end

		--If the marked target is still valid, continue the lock countdown
		if markedTarget and markedTime then
			local elapsed = os.clock() - markedTime

			--Check if lock time has elapsed
			if elapsed >= addonConfig.RadarLockTime then
				markedState = 2
				addonEvent:Fire(script.Name, "SetTargetData", player, markedPos, markedTarget)
			end
		end
	end
end

return module