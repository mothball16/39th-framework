--[[       
DRAGOON TANK SYSTEM
Smoke Launcher
1.2.0
--]]

local module = {}

--// Services
local replicatedStorage = game:GetService("ReplicatedStorage")
local userInput = game:GetService("UserInputService")
local debris = game:GetService("Debris")
local players = game:GetService("Players")
local tweens = game:GetService("TweenService")
local guiservice = game:GetService("GuiService")

local player = game.Players.LocalPlayer
local playerCam = game.Workspace.CurrentCamera

--// Folders
local assets = replicatedStorage.DTS_Assets
local modules = assets.Modules
local projectiles = assets.Projectiles

local hudMod = require(modules.HUDModule)
local fxmod = require(modules.FXModule)
local config = require(assets.GlobalSettings)

local sphInstall = replicatedStorage:FindFirstChild("SPH_Assets") --Spearhead compat
local bridgeNet
if sphInstall then 
	bridgeNet = require(sphInstall.Modules.BridgeNet)
	partCache = require(sphInstall.Modules.PartCache)
else  
	bridgeNet = require(modules.BridgeNet) 
end

local workspaceFolder = game.Workspace.DTS_Workspace
local bulletContainer = workspaceFolder.Temp

local fastCastClient = assets.Events.BallisticReplication
local forceReload = assets.Events.ReloadEvent
local playerReload = bridgeNet.CreateBridge("PlayerReload2")
local attSet = bridgeNet.CreateBridge("attributeSet") -- Client > Server 
local addonEvent = bridgeNet.CreateBridge("AddonEvent")

--// Functions
local function GetMuzzleCFrames(grip:BasePart)
	local cframes = {}
	for _, attach:Attachment in grip:GetChildren() do
		if not attach:IsA("Attachment") then continue end
		table.insert(cframes, attach.WorldCFrame)
	end
	return cframes
end

local function FireSmoke(weaponActive, vehicle, addonObj, gun, addonConfig)
	if table.find(addonConfig.AddonCodeFiring, weaponActive)==nil then return end

	--// Firing preparations, autoreload and cycle time
	local reloading = addonObj:GetAttribute("internal_Reloading")
	local chamber = addonObj:GetAttribute("internal_Chambered")
	local cycled = addonObj:GetAttribute("internal_Cycled")
	local gunAmmo = addonObj:GetAttribute("clipAmmo")

	--Autoreload
	if gunAmmo<=0 and not reloading and not chamber then
		playerReload:Fire(vehicle, addonObj, gun.Grip)
		return 
	end

	--// Firing Code
	if not reloading and chamber and cycled and gunAmmo>0 then
		addonObj:SetAttribute("internal_Cycled", false)
		fastCastClient:Fire("FireFX", player, player, gun.Grip, 10)

		--Firing action
		local muzzleCFrames = GetMuzzleCFrames(gun.Grip)
		local spreadCFrame = CFrame.Angles(math.rad(math.random(-addonConfig.ShellSpread[1],addonConfig.ShellSpread[2])), math.rad(math.random(-addonConfig.ShellSpread[1],addonConfig.ShellSpread[2])), 0)
		addonEvent:Fire(script.Name, "FireShell", vehicle, addonObj, gun.Grip, muzzleCFrames, spreadCFrame, addonConfig.ShellVelocity)
		--module.FireShell(vehicle:Model, addonObj:Model, grip:BasePart, spreadCFrame:CFrame, shellVelocity:number)

		task.wait(60/addonConfig.Firerate)
		addonObj:SetAttribute("internal_Cycled", true)
	end
end

--// Core Functions
function module.InputBegan(inputObj:InputObject, weaponActive, vehicle, addonObj, gun, addonConfig, guiw)
	if table.find(addonConfig.AddonCodeFiring, weaponActive)==nil then return end

	if inputObj.KeyCode == addonConfig.CounterKeybind then
		--FireSmoke(addonObj, gun, wpnConfig)		
		FireSmoke(weaponActive, vehicle, addonObj, gun, addonConfig)
	end
end

function module.LoadModule(addonObj:Folder, vehicle, guiw)
	local attributes = {
		["internal_Reloading"] = false,
		["internal_ReloadStart"] = 0,
		["internal_Cycled"] = true,
		["internal_CycleStart"] = 0,
		["internal_Chambered"] = true,
		["internal_Firemode"] = 0,
		["internal_BulletsFired"] = 0,
		["internal_TgtAngle"] = 0,
		["internal_CurAngle"] = 0,
		["internal_Zero"] = 0,
		["internal_Range"] = 0,
		["internal_AimDist"] = 0,
		["internal_VehAngle"] = 0,
		["internal_Infrared"] = false,
		["internal_NightVis"] = false,
	}

	--Replicate attributes
	for key, value in attributes do
		local existing = addonObj:GetAttribute(key)
		if existing~=nil then continue end
		attSet:Fire(addonObj, key, value, script)
	end

	addonObj:GetAttributeChangedSignal("internal_Reloading"):Connect(function()
		local reloading = addonObj:GetAttribute("internal_Reloading")
		if reloading then
			addonObj:SetAttribute("internal_ReloadStart", os.clock())
		else
			guiw.Reload:Play()
		end
	end)

	addonEvent:Fire(script.Name, "AutoRemoveTag", addonObj, addonObj.Parent.Parent)
end

function module.AutoRemoveTag(addonObj:Model, vehicle:Model)
	if vehicle:GetAttribute("Vehicle_Countermeasures")~= nil then return end
	vehicle:SetAttribute("Vehicle_Countermeasures", false)

	local wepStats = require(addonObj:FindFirstChildWhichIsA("ModuleScript"))
	if not wepStats.CounterMissiles then return end
	local removeTask:thread

	--addonObj:SetAttribute("internal_Reloading", false)
	--addonObj:SetAttribute("internal_Chambered", false)

	vehicle:GetAttributeChangedSignal("Vehicle_Countermeasures"):Connect(function()
		local newValue = vehicle:GetAttribute("Vehicle_Countermeasures")
		if not newValue then return end

		if removeTask then task.cancel(removeTask) end
		removeTask = task.delay(wepStats.CounterDuration, function()
			vehicle:SetAttribute("Vehicle_Countermeasures", false)
			vehicle:SetAttribute("Vehicle_CounterLocation", Vector3.zero)
			
			for _, tag in wepStats.CounterTypes do
				vehicle:RemoveTag(tag)
			end
		end)
	end)
end

function module.RemoveCountermeasures(addonObj:Model, vehicle:Model)
	local wepStats = require(addonObj:FindFirstChildWhichIsA("ModuleScript"))
	
	vehicle:SetAttribute("Vehicle_Countermeasures", false)
	vehicle:SetAttribute("Vehicle_CounterLocation", Vector3.zero)
	for _, tag in wepStats.CounterTypes do
		vehicle:RemoveTag(tag)
	end
end


function module.FireShell(vehicle:Model, addonObj:Model, grip:BasePart, muzzles:{CFrame}, spreadCFrame:CFrame, shellVelocity:number)
	local wepStats = require(addonObj:FindFirstChildWhichIsA("ModuleScript"))

	local grenadeFX = projectiles:FindFirstChild(wepStats.ShellModel or "SmokeGrenade")
	if not grenadeFX then return end

	local gunAmmo = addonObj:GetAttribute("clipAmmo")
	local reloading = addonObj:GetAttribute("internal_Reloading")
	local chamber = addonObj:GetAttribute("internal_Chambered")
	if gunAmmo <=0 or reloading or not chamber then return end

	--Deploy smoke grenades
	for _, muzzle:CFrame in muzzles do
		local bulletDirection = (muzzle * spreadCFrame).LookVector
		local bulletVelocity = (bulletDirection.Unit * shellVelocity * 3.5) -- 1 Meter = ~3.5 Studs (According to the dev forum)

		local newGrenade = grenadeFX:Clone()
		--newGrenade.CanCollide = false
		newGrenade.Parent = bulletContainer
		newGrenade:PivotTo(muzzle)
		newGrenade:ApplyImpulse(bulletVelocity)

		fxmod.PlayAllLocalFX(newGrenade)

		debris:AddItem(newGrenade, wepStats.CounterDuration)
		--task.delay(0.5, function()
		--	newGrenade.CanCollide = true
		--end)
	end
	grip.Fire:Play()

	--Enable countermeasures
	if wepStats.CounterMissiles then
		vehicle:SetAttribute("Vehicle_Countermeasures", true)
		vehicle:SetAttribute("Vehicle_CounterLocation", grip.Position)
		for _, tag in wepStats.CounterTypes do
			vehicle:AddTag(tag)
		end
	end
	
	--Proceed with firing logic
	if chamber and not reloading then
		addonObj:SetAttribute("internal_Chambered", false)
		if gunAmmo > 0 then
			addonObj:SetAttribute("clipAmmo", gunAmmo-1)
			gunAmmo = addonObj:GetAttribute("clipAmmo")

			if gunAmmo <= 0 then --fired the last bullet, now we have to reload
				forceReload:Fire(nil, vehicle, addonObj, grip)
			else
				addonObj:SetAttribute("internal_Chambered", true)
			end
		end
	end
end

--deltaTime, weaponActive, vehicle, DataLocal["WeaponModel"], DataLocal["Gun"], DataLocal["Config"], addonGui, cameraMode, userInput:GetMouseDelta())
function module.RenderLoop(dt, weaponActive, vehicle, addonObj, gun, addonConfig, wpnGui, cameraMode, mouseDelta) --Runs on renderstepped
	local aiming = table.find(addonConfig.AddonCodeAiming, weaponActive)~=nil
	local firing = table.find(addonConfig.AddonCodeFiring, weaponActive)~=nil

	if aiming then 
		hudMod.UpdateSights(addonObj, wpnGui, cameraMode>=1, nil, nil, nil, nil, nil, mouseDelta, dt, addonConfig)
		
		local isTarget = vehicle:HasTag("Dragoon_Target")
		local warningSound = wpnGui.Warning
		if isTarget and not warningSound.Playing  then
			warningSound:Play()
		elseif not isTarget and warningSound.Playing  then
			warningSound:Stop()
		end
	end
	wpnGui.Visible = firing
end


function module.RunLoop(dt, weaponActive, vehicle, addonObj, gun, addonConfig, wpnGui) --Runs on heartbeat
	local countermeasures = vehicle:GetAttribute("Vehicle_Countermeasures")
	local lastPos = vehicle:GetAttribute("Vehicle_CounterLocation") 
	
	if addonConfig.CounterRadius and countermeasures and lastPos and lastPos~=Vector3.zero then
		local distance = (gun.Grip.Position - lastPos).Magnitude
		if distance > addonConfig.CounterRadius then
			vehicle:SetAttribute("Vehicle_CounterLocation", Vector3.zero)
			addonEvent:Fire(script.Name, "RemoveCountermeasures", addonObj, addonObj.Parent.Parent)
		end
	end
	
end

return module