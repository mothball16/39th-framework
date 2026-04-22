local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Charm = require(Packages.Charm)
local sph = require(ReplicatedStorage.SPH_Framework.Core.GameAccess)
local assets = sph.assets
local modules = sph.framework
local config = sph.config
local Enums = require(modules.Core.Enums)
local bulletHandler = require(modules.Ballistics.BulletHandler)
local shellEjection = require(modules.Weapons.ShellEjection)
local weldMod = require(modules.Weapons.WeldMod)
local bridgeNet = require(modules.Network.BridgeNet)
local weaponPrefsClient = require(modules.Weapons.WeaponPrefsClient)
local weaponStatLocator = require(modules.Weapons.WeaponStatLocator)
local holosightMod = require(modules.Weapons.Mods.Holosight)

local RecoilModule = require(modules.Weapons.Recoil.Default)

local CharacterStateModule = require(ReplicatedStorage.SPH_Framework.State.CharacterState)
local WeaponStateModule = require(ReplicatedStorage.SPH_Framework.State.WeaponState)
local AnimationEvents = require(script.Parent.AnimationEvents)
local Player = game.Players.LocalPlayer
local Camera = game.Workspace.CurrentCamera

local storageCFrame = CFrame.new(1000000, 0, 0)
local defaultCameraMode = Player.CameraMode

local WC = {
	holdingM1 = false,
	cycled = true,
	canFire = true,
	canBipod = false,
	bipodRayIgnore = {},
	ejected = true,
	cancelReload = false,
	bulletsCurrentlyFired = 0,
	ubglAmmo = nil,
	sights = {},
	lastGunModel = nil,

	-- Dependencies
	player = nil,
	character = nil,
	humanoid = nil,
	humanoidRootPart = nil,
	camera = nil,
	viewmodelRig = nil,
	thirdPersonRig = nil,
	rigType = nil,

	holosightMod = nil,
	InputController = nil,
	
	RefreshViewmodel = nil,
}

local weaponState: WeaponStateModule.WeaponState
local State: CharacterStateModule.CharacterState

WC.switchWeapon = bridgeNet.CreateBridge("SwitchWeapon")
WC.playerFire = bridgeNet.CreateBridge("PlayerFire")
WC.playSound = bridgeNet.CreateBridge("PlaySound")
WC.repReload = bridgeNet.CreateBridge("Reload")
WC.repChamber = bridgeNet.CreateBridge("PlayerChamber")
WC.moveBolt = bridgeNet.CreateBridge("MoveBolt")
WC.switchFireMode = bridgeNet.CreateBridge("SwitchFireMode")
WC.playerDropGun = bridgeNet.CreateBridge("PlayerDropGun")
WC.playerToggleAttachment = bridgeNet.CreateBridge("PlayerToggleAttachment")
WC.repBoltOpen = bridgeNet.CreateBridge("RepBoltOpen")
WC.magGrab = bridgeNet.CreateBridge("MagGrab")

function WC._applyPersistedWeaponPrefs(weaponName)
	weaponPrefsClient.applyPersisted(weaponName, State, weaponState, WC)
end

local function findChildModelWithMainPartChild(gun, partName)
	if not gun then
		return nil
	end
	for _, child in ipairs(gun:GetChildren()) do
		if child:IsA("Model") then
			local main = child:FindFirstChild("Main")
			if main and main:FindFirstChild(partName) then
				return child
			end
		end
	end
	return nil
end

local function findFireSoundInstance(gun)
	local mount = findChildModelWithMainPartChild(gun, "Fire")
	if mount and mount.Main:FindFirstChild("Fire") then
		return mount.Main.Fire
	end
	return nil
end

function WC.Initialize(params)
	WC.player = params.player
	WC.character = params.character
	WC.humanoid = params.humanoid
	WC.humanoidRootPart = params.humanoidRootPart
	WC.camera = params.camera
	WC.viewmodelRig = params.viewmodelRig
	WC.thirdPersonRig = params.thirdPersonRig
	WC.rigType = params.rigType
	weaponState = params.weaponState
	State = params.state
	
	WC.bipodRayIgnore = {params.character}
	WC.InputController = params.InputController
	WC.RefreshViewmodel = params.RefreshViewmodel

	WC.holosightMod = holosightMod.new(weaponState)

	WC.character.ChildAdded:Connect(function(child)
		WC.Equip(child)
	end)
	
	WC.character.ChildRemoved:Connect(function(child)
		if State.equippedTool() and child == State.equippedTool() then
			WC.Unequip(child)
		end
	end)

	Charm.subscribe(State.aiming, WC.SyncAiming)
	Charm.subscribe(State.firstPerson, WC.SyncFirstPerson)
	Charm.subscribe(State.sprinting, WC.SyncSprinting)

	Charm.subscribe(weaponState.sightIndex, WC.SyncSightIndex)
	Charm.subscribe(weaponState.flashlightEnabled, WC.SyncFlashlightEnabled)
	Charm.subscribe(weaponState.bipodEnabled, WC.SyncBipodEnabled)
	Charm.subscribe(weaponState.fireMode, WC.SyncFireMode)
	Charm.subscribe(weaponState.chambering, WC.SyncChambering)

	-- Listen for animation events via signals
	AnimationEvents.KeyframeReached:Connect(WC.OnKeyframeReached)
	AnimationEvents.AnimationStopped:Connect(WC.OnAnimationStopped)
end

function WC.UpdateAttachmentsVisibility()
	if not State.equippedTool() then return end
	
	local isFirstPerson = State.firstPerson()
	local flashlightOn = weaponState.flashlightEnabled()
	local tpModel = WC.GetThirdPersonGunModel()
	
	local function updateLight(model, enabled)
		if not model then return end
		if model.Grip:FindFirstChild("Flashlight") then
			local light = model.Grip.Flashlight:FindFirstChildWhichIsA("Light")
			if light then light.Enabled = enabled end
		end
		for _, child in ipairs(model:GetChildren()) do
			if child:IsA("Model") and child:FindFirstChild("Main") then
				local flashPart = child.Main:FindFirstChild("Flashlight")
				if flashPart then
					local light = flashPart:FindFirstChildWhichIsA("Light")
					if light then light.Enabled = enabled end
				end
			end
		end
	end
	
	updateLight(weaponState.gunModel(), flashlightOn and isFirstPerson)
	updateLight(tpModel, flashlightOn and not isFirstPerson)
end

function WC.SyncFlashlightEnabled(enabled)
	if not State.equippedTool() then return end
	if weaponPrefsClient.isApplying then
		WC.UpdateAttachmentsVisibility()
		return
	end
	WC.PlayRepSound("Button")
	WC.playerToggleAttachment:Fire(0, enabled)
	WC.UpdateAttachmentsVisibility()
end

function WC.SyncBipodEnabled(enabled)
	if not State.equippedTool() then return end
	local bipodModel = weaponState.gunModel()
	local bipMount = findChildModelWithMainPartChild(weaponState.gunModel(), "Bipod")
	if bipMount then
		bipodModel = bipMount
	end
	if bipodModel then
		WC.ToggleBipod(bipodModel, enabled)
		if weaponPrefsClient.isApplying then
			return
		end
		WC.PlayRepSound("Switch")
		WC.playerToggleAttachment:Fire(2, enabled)
	end
end

function WC.SyncFireMode(mode)
	if not State.equippedTool() then return end
	if weaponPrefsClient.isApplying then
		return
	end
	WC.switchFireMode:Fire(mode)
end


function WC.SyncAiming(aiming)
	if aiming then
		-- effects n stuff
		local ADSMeshEnabled = weaponState.adsMeshEnabledForActiveSight()
		WC.PlayRepSound("AimUp")
		WC.ToggleADSMesh(ADSMeshEnabled)
		if not config.lockFirstPerson then
			Player.CameraMode = Enum.CameraMode.LockFirstPerson
		end

		-- ready the character
		State.sprinting(false)
		weaponState.holdStance(Enums.HoldStance.Ready)
	else
		WC.PlayRepSound("AimDown")
		WC.ToggleADSMesh(false)

		if not config.lockFirstPerson then
			Player.CameraMode = defaultCameraMode
		end
	end
end

function WC.SyncFirstPerson(isFirstPerson)
	if isFirstPerson then
		if State.equippedTool() then
			WC.InputController.BindAiming()
		end
	else
		WC.InputController.UnbindAiming()
	end
	WC.UpdateAttachmentsVisibility()
end

function WC.SyncSprinting(sprinting)
	if sprinting then
		State.aiming(false)
		weaponState.holdStance(Enums.HoldStance.Ready)
		WC.holdingM1 = false
	end
end

function WC.SyncSightIndex(index)
	if weaponState:ADSMeshLayerEnabled(index) then
		WC.ToggleADSMesh(true)
	else
		WC.ToggleADSMesh(false)
	end
end



function WC.PlayRepSound(soundName)
	local ws = weaponState.wepStats()
	if not State.dead() and ws then
		local soundToPlay
		local gm = weaponState.gunModel()
		if weaponState.ubglActive() then
			soundToPlay = gm.Grip:FindFirstChild("UBGL_" .. soundName)
			if not soundToPlay then
				soundToPlay = gm.Grip:FindFirstChild(soundName)
				if soundName == "Fire" then
					soundToPlay = findFireSoundInstance(gm) or soundToPlay
				end
			end
		else
			soundToPlay = gm.Grip:FindFirstChild(soundName)
			if soundName == "Fire" then
				soundToPlay = findFireSoundInstance(gm) or soundToPlay
			end
		end

		if soundToPlay and State.equippedTool() then
			if State.firstPerson() then
				soundToPlay:Play()
			else
				local clonedSound = soundToPlay:Clone()
				clonedSound.Parent = WC.humanoidRootPart
				clonedSound:Play()
				Debris:AddItem(clonedSound, clonedSound.TimeLength)
			end
			WC.playSound:Fire(soundName, State.firstPerson())
		end
	end
end

function WC.GetCurrentWepStats()
	if weaponState.ubglActive() then
		local ws = weaponState.wepStats()
		return ws and ws.getStatsForMode(4)
	else
		return weaponState.wepStats()
	end
end

function WC.IsLoaded()
	local currentStats = WC.GetCurrentWepStats()
	if weaponState.ubglActive() then
		return WC.ubglAmmo and WC.ubglAmmo.Value > 0
	else
		return not currentStats.openBolt and State.equippedTool().Chambered.Value or currentStats.openBolt and weaponState.gunAmmo.MagAmmo.Value > 0
	end
end

function WC.GetMuzzlePoint(gunModel)
	if weaponState.ubglActive() then
		local ubglMuzzle = gunModel.Grip:FindFirstChild("UBGLMuzzle")
		if ubglMuzzle then return ubglMuzzle end
	end
	return gunModel.Grip.Muzzle
end

function WC.MoveBolt(direction:CFrame, silent:boolean)
	local ws = weaponState.wepStats()
	bulletHandler.MoveBolt(weaponState.gunModel(), ws, direction, weaponState.gunAmmo.MagAmmo.Value)
	bulletHandler.MoveBolt(WC.thirdPersonRig.Weapon:FindFirstChildWhichIsA("Model"), ws, direction, weaponState.gunAmmo.MagAmmo.Value)
	if weaponState.gunAmmo.MagAmmo.Value <= 0 and not silent then
		WC.PlayRepSound("Empty")
	end
	WC.moveBolt:Fire(direction, weaponState.gunAmmo.MagAmmo.Value)
end

function WC.ToggleADSMesh(toggle)
	if not weaponState.hasAdsMeshLayers() then
		return
	end

	local ws = weaponState.wepStats()
	local aimingTime = (ws and ws.aimTime and ws.aimTime / 20) or 0.2

	for _, child in ipairs(weaponState.gunModel():GetDescendants()) do
		if child.Name == "REG" then
			child.Transparency = toggle and 1 or 0
		elseif child.Name == "ADS" then
			child.Transparency = toggle and 0 or 1
		end
	end
end

function WC.ToggleBipod(bipodModel, toggle)
	for _, bipObject in ipairs(bipodModel:GetChildren()) do
		if bipObject.Name == "Bipod_On" then
			bipObject.Transparency = toggle and 0 or 1
		elseif bipObject.Name == "Bipod_Off" then
			bipObject.Transparency = toggle and 1 or 0
		end
	end
end

function WC.SetProjectileTransparency(model, transparency)
	local ws = weaponState.wepStats()
	if not ws or ws.projectile == "Bullet" or not model then return end
	local projectile = model:FindFirstChild(ws.projectile)
	if projectile then
		projectile.LocalTransparencyModifier = transparency
		for _, child in ipairs(projectile:GetDescendants()) do
			if child:IsA("BasePart") then child.LocalTransparencyModifier = transparency end
		end
	end
end

function WC.EjectShell()
	WC.ejected = true
	local ws = weaponState.wepStats()
	if ws and ws.shellEject then
		if State.firstPerson() then
			shellEjection.ejectShell(WC.player, State.equippedTool(), weaponState.gunModel())
		else
			shellEjection.ejectShell(WC.player, State.equippedTool(), WC.thirdPersonRig.Weapon:FindFirstChildWhichIsA("Model"))
		end
	end
end

function WC.GetThirdPersonGunModel()
	return WC.thirdPersonRig.Weapon:FindFirstChildWhichIsA("Model")
end

function WC.SwitchFireMode()
	local mode = weaponState.fireMode()
	local ws = weaponState.wepStats()
	if not ws then
		return
	end
	repeat
		mode += 1
		if mode > 5 then mode = 0 break end
	until ws.fireSwitch[mode]
	weaponState.fireMode(mode)
end


function WC.Unequip(tool)
	weaponState.equipping(false)
	WC.viewmodelRig.AnimBase.CFrame = storageCFrame
	WC.lastGunModel = weaponState.gunModel()
	
	WC.switchWeapon:Fire()
	if tool == State.equippedTool() then
		weaponPrefsClient.set(tool.Name, {
			laserEnabled = weaponState.laserEnabled(),
			flashlightEnabled = weaponState.flashlightEnabled(),
			bipodEnabled = weaponState.bipodEnabled(),
			fireMode = weaponState.fireMode(),
			aimSens = weaponState.aimSens(),
			sightIndex = weaponState.sightIndex(),
		})
		State.equippedTool(nil)
		weaponState:Reset()
	end
	UserInputService.MouseIconEnabled = true
	AnimationEvents.StopAllRequested:Fire()

	if config.lockFirstPerson then
		WC.player.CameraMode = Enum.CameraMode.Classic
	end

	WC.sights = {}

	WC.InputController.UnbindGunInputs()
end

function WC.Equip(newChild)
	if
		not newChild:FindFirstChild("SPH_Weapon")
		or (newChild:FindFirstChild("SPH_Weapon") and not assets.WeaponModels:FindFirstChild(newChild.Name))
		or State.dead()
		or (WC.humanoid.Sit and not State.vehicleSeated())
	then
		return
	end

	UserInputService.MouseIconEnabled = false

	weaponState:Reset()
	weaponState.equipping(true)

	State.equippedTool(newChild)
	weaponState.wepStats(weaponStatLocator.getWeaponStats(State.equippedTool().SPH_Weapon))

	WC.cycled = true
	WC.switchWeapon:Fire(newChild)


	local ws = weaponState.wepStats()
	if ws and ws.PunchSpeed then
		weaponState.RecoilPos.s = ws.PunchSpeed
		weaponState.RecoilDir.s = ws.PunchSpeed
		weaponState.RecoilUp.s = ws.PunchSpeed
	end
	if ws and ws.PunchDamper then
		weaponState.RecoilPos.d = ws.PunchDamper
		weaponState.RecoilDir.d = ws.PunchDamper
		weaponState.RecoilUp.d = ws.PunchDamper
	end



	-- fallbacks
	if ws and (not ws.operationType or type(ws.operationType) == "string") then
		ws.operationType = 1
	end
	if ws and not ws.magType then
		ws.magType = 1
	end

	local oldGun = WC.viewmodelRig.Weapon:FindFirstChildWhichIsA("Model")
	if oldGun then
		oldGun:Destroy()
	end

	
	local gun = assets.WeaponModels:FindFirstChild(newChild.Name):Clone()
	weldMod.WeldModel(gun, gun.Grip, false)

	for _, partName in ipairs(ws.rigParts) do
		if gun:FindFirstChild(partName) then
			gun.Grip["Grip_"..partName]:Destroy()
			local newMotor = weldMod.M6D(gun.Grip, gun[partName])
			newMotor.Name = partName
			newMotor.Parent = gun.Grip
		end
	end

	for _, part in ipairs(gun:GetDescendants()) do
		if part.Name == "SightReticle" then table.insert(WC.sights, part) end
	end

	gun.Parent = WC.viewmodelRig.Weapon
	weaponState.gunModel(gun)

	weaponState.maid:GiveTask(weldMod.BlankM6D(WC.viewmodelRig.AnimBase, gun.Grip))

	if State.firstPerson() then
		WC.RefreshViewmodel()
	end
	WC.InputController.BindGunInputs(State.firstPerson())

	AnimationEvents.WeaponEquipRequested:Fire()
	AnimationEvents.WeaponIdleRequested:Fire()

	if not ws then return end
	if ws.openBolt or not State.equippedTool().Chambered.Value then
		WC.SetProjectileTransparency(weaponState.gunModel(), 1)
	end

	weaponState.gunAmmo = State.equippedTool():WaitForChild("Ammo")
	weaponState.localAmmo(weaponState.gunAmmo.MagAmmo.Value)
	if ws.hasUBGL then
		WC.ubglAmmo = newChild:FindFirstChild("UBGLAmmo")
		local ubglAmmoPool = newChild:FindFirstChild("UBGLAmmoPool")
		if not WC.ubglAmmo then
			WC.ubglAmmo = Instance.new("IntValue", newChild)
			WC.ubglAmmo.Name = "UBGLAmmo"
			local totalStartAmmo = ws.ubgl.startAmmoPool or 6
			WC.ubglAmmo.Value = (totalStartAmmo > 0 and (not ubglAmmoPool or ubglAmmoPool.Value > 0)) and 1 or 0
		end
		if not ubglAmmoPool then
			ubglAmmoPool = Instance.new("DoubleConstrainedValue", newChild)
			ubglAmmoPool.Name = "UBGLAmmoPool"
			ubglAmmoPool.MaxValue = ws.ubgl.maxAmmoPool or 12
			local totalStartAmmo = ws.ubgl.startAmmoPool or 6
			ubglAmmoPool.Value = totalStartAmmo > 0 and (totalStartAmmo - WC.ubglAmmo.Value) or 0
		end

		if ws.ubgl.reloadAnim then
			local animSpeed = ws.reloadSpeedModifier
			AnimationEvents.PlayAnimationRequested:Fire(ws.ubgl.reloadAnim, { speed = animSpeed, transSpeed = 0.17 }, "Reload", "reload")
		end
	else
		WC.ubglAmmo = nil
	end

	if not State.equippedTool().BoltReady.Value then
		WC.MoveBolt(ws.boltDist, true)
	end

	if config.lockFirstPerson then WC.player.CameraMode = Enum.CameraMode.LockFirstPerson end
	weaponState.fireMode(State.equippedTool().FireMode.Value)
	weaponState.holdStance(Enums.HoldStance.Ready)

	WC._applyPersistedWeaponPrefs(newChild.Name)

	task.delay(1, function() WC.lastGunModel = newChild end)
end

function WC.OnTriggerIntent(inputState, inputObject)
	local inputBegan = Enum.UserInputState.Begin
	if inputState == inputBegan then
		WC.cancelReload = true
		if not (State.sprinting() or weaponState.reloading()) then
			WC.holdingM1 = true
			if not WC.IsLoaded() and not (State.equippedTool():GetAttribute("FireMode") == Enums.FireModes.Manual and State.equippedTool():GetAttribute("MagAmmo") > 0) then
				WC.PlayRepSound("Click")
			end
		end
	else
		WC.holdingM1 = false
		WC.canFire = true
		WC.bulletsCurrentlyFired = 0
	end
end

function WC.OnDropGunIntent(inputState, inputObject)
	local inputBegan = Enum.UserInputState.Begin
	if inputState == inputBegan then
		WC.Unequip(State.equippedTool())
		WC.playerDropGun:Fire()
	end
end

function WC.OnReloadIntent(inputState, inputObject)
	local inputBegan = Enum.UserInputState.Begin
	if inputState ~= inputBegan or not weaponState.canManipulate() or not WC.cycled then return end
	weaponState.holdStance(Enums.HoldStance.Ready)
	State.aiming(false)
	if weaponState.ubglActive() then
		local ubglAmmoPool = State.equippedTool():FindFirstChild("UBGLAmmoPool")
		if WC.ubglAmmo and WC.ubglAmmo.Value == 0 and ubglAmmoPool and ubglAmmoPool.Value > 0 then
			WC.cancelReload = false
			AnimationEvents.ReloadRequested:Fire(WC.lastGunModel and WC.lastGunModel.Name)
		end
	else
		local ws = weaponState.wepStats()
		if not ws then
			return
		end
		if ws.infiniteAmmo or weaponState.gunAmmo.ArcadeAmmoPool.Value > 0 then
			if (ws.openBolt and weaponState.gunAmmo.MagAmmo.Value < weaponState.gunAmmo.MagAmmo.MaxValue) then
				WC.cancelReload = false
				AnimationEvents.ReloadRequested:Fire(WC.lastGunModel and WC.lastGunModel.Name)
			else
				if (ws.operationType == 4 and State.equippedTool().Chambered.Value)
					or (ws.operationType == 3 and weaponState.gunAmmo.MagAmmo.Value + 1 >= weaponState.gunAmmo.MagAmmo.MaxValue)
					or (ws.operationType == 2 and weaponState.gunAmmo.MagAmmo.Value >= weaponState.gunAmmo.MagAmmo.MaxValue) then
					return
				end
				WC.cancelReload = false
				AnimationEvents.ReloadRequested:Fire(WC.lastGunModel and WC.lastGunModel.Name)
			end
		end
	end
	
end

function WC.OnChamberIntent(inputState, inputObject)
	local inputBegan = Enum.UserInputState.Begin
	if inputState == inputBegan and weaponState.canManipulate() and WC.cycled then
		weaponState.chambering(true)
	end
end

function WC.SyncChambering(chambering)
	if chambering then
		weaponState.holdStance(Enums.HoldStance.Ready)
		State.aiming(false)
	end
end

function WC.OnSwitchSightsIntent(inputState, inputObject)
	local inputBegan = Enum.UserInputState.Begin
	if inputState == inputBegan and State.aiming() and weaponState.gunModel():FindFirstChild("AimPart2") then
		local tempIndex = weaponState.sightIndex() + 1
		if weaponState.gunModel():FindFirstChild("AimPart"..tempIndex) then
			weaponState.sightIndex(tempIndex)
			WC.PlayRepSound("AimUp")
		else
			weaponState.sightIndex(1)
			WC.PlayRepSound("AimDown")
		end
	end
end

function WC.OnSwitchFireModeIntent(inputState, inputObject)
	local inputBegan = Enum.UserInputState.Begin
	if inputState == inputBegan then
		AnimationEvents.SwitchFireModeAnimRequested:Fire()
	end
end

function WC.OnToggleFlashlightIntent(inputState, inputObject)
	local inputBegan = Enum.UserInputState.Begin
	if inputState == inputBegan then
		weaponState.flashlightEnabled(not weaponState.flashlightEnabled())
	end
end

function WC.OnAimIntent(inputState, inputObject)
	local inputBegan = inputState == Enum.UserInputState.Begin
	if not UserInputService.TouchEnabled and not config.toggleAiming then -- Hold aiming
		if inputBegan
			and State.firstPerson()
			and not State.freeLook()
			and weaponState.canTrackAimInput() then
			weaponState.aimHeld(true)
			State.aiming(true)
		else
			weaponState.aimHeld(false)
			State.aiming(false)
		end
	elseif inputBegan then -- Mobile and toggle aiming
		if State.firstPerson()
		and not State.freeLook()
		and weaponState.canTrackAimInput()
		and not State.aiming() then
			weaponState.aimHeld(true)
			State.aiming(true)
		else
			weaponState.aimHeld(false)
			State.aiming(false)
		end
	end
end

function RANDF(Min, Max)
	return Min + math.random() * Max
end

function RAND(Min, Max, Accuracy)
	local Inverse = 1 / (Accuracy or 1)
	return (math.random(Min * Inverse, Max * Inverse) / Inverse)
end

function RAND2(mean,range)
	return (math.random()-0.5)*range + mean
end

function CFRot(CF)
	return CFrame.Angles(CF:ToEulerAnglesXYZ())
end

function PunchCalc(PunchBase,Dir,Default)
	if not Dir then
		return PunchCalc(PunchBase,Default)
	elseif Dir == "Up" or Dir == "Left" or Dir == "ACW" then
		return PunchBase
	elseif Dir == "Side" or Dir == "Both" then
		return RAND2(0, PunchBase * 2)
	elseif Dir == "Down" or Dir == "Right" or Dir == "CW" then
		return -PunchBase
	else
		return PunchCalc(PunchBase,Default)
	end
end

function RecoilCalc(Recoil,Dir,Default)
	if not Dir then
		return RecoilCalc(Recoil,Default)
	elseif Dir == "Up" or Dir == "Left" then
		return Recoil
	elseif Dir == "Side" or Dir == "Both" then
		return RAND2(0, Recoil*2)
	elseif Dir == "Down" or Dir == "Right" then
		return -Recoil
	else
		return RecoilCalc(Recoil,Default)
	end
end

local SP = require(modules.Weapons.Spring.Default)

function WC.PerformRecoil(wepStats)
	coroutine.wrap(function()
		local vr, hr, vP, hP, dP

		local VRecoil = RANDF(wepStats.VRecoil[1], wepStats.VRecoil[2])/1000
		local HRecoil = RANDF(wepStats.HRecoil[1], wepStats.HRecoil[2])/1000
		local finalRecoilPunch = wepStats.RecoilPunch
		
		-- if State.aiming() then
		-- 	VRecoil /= wepStats.AimRecoilReduction
		-- 	HRecoil /= wepStats.AimRecoilReduction
		-- end

		vr = RecoilCalc(VRecoil, wepStats.VRecoilDir, "Up") 
		hr = RecoilCalc(HRecoil, wepStats.HRecoilDir, "Side")

		vP = PunchCalc(wepStats.VPunchBase, wepStats.VPunchDir,"Up") 
		hP = PunchCalc(wepStats.HPunchBase, wepStats.HPunchDir,"Side")
		dP = PunchCalc(wepStats.DPunchBase, wepStats.DPunchDir,"Side")


		if State.aiming() then
			vr /= wepStats.AimRecoilReduction
			hr /= wepStats.AimRecoilReduction
			vP /= wepStats.AimRotationalPunchReduction
			hP /= wepStats.AimRotationalPunchReduction
			dP /= wepStats.AimRotationalPunchReduction
			finalRecoilPunch /= wepStats.AimBackwardPunchReduction
		end

		if weaponState.bipodEnabled() then
			vr  = vr/3
			hr = hr/3

			vP = vP*0.75

			hP = hP/2.5
			dP = dP/2.5

			weaponState.RecoilCF = RecoilModule.BipodRecoil(
				weaponState.RecoilCF, finalRecoilPunch, weaponState.RecoilFactor,vP,hP,dP)
		else
			weaponState.RecoilCF = RecoilModule.Recoil(
				weaponState.RecoilCF, finalRecoilPunch, weaponState.RecoilFactor,vP,hP,dP)
		end

		weaponState.RecoilPos.t = weaponState.RecoilCF.Position
		weaponState.RecoilDir.t = weaponState.RecoilCF.LookVector
		weaponState.RecoilUp.t = weaponState.RecoilCF.UpVector
		
		weaponState.CameraSpring.t = weaponState.CameraSpring.t + Vector3.new(vr, hr, 0)
		weaponState.CameraSpring.p = weaponState.CameraSpring.p + Vector3.new(vr, hr, 0) * 0.5
		local duration = 0.25 --ServerConfig.AimRecoverDuration
		task.wait(duration/5 * weaponState.CameraSpring.s / SP.cs)
		--cwait(duration/5 * CameraSpring.s / SP.cs)
		local t = 0
		if wepStats.AimRecoverDuration then
			duration = wepStats.AimRecoverDuration
		end
		while t <= duration do
			local step = RunService.Heartbeat:Wait()
			t = t + step
			weaponState.CameraSpring.t = weaponState.CameraSpring.t - Vector3.new(vr, hr, 0) 
				* wepStats.AimRecover * step / duration
		end
	end)()
	
end



function WC.UpdateHeartbeat(dt)
	if not State.equippedTool() or State.dead() then return end
	local ws = weaponState.wepStats()
	if not ws then
		return
	end
	
	-- General state checks: prevents execution if sprinting, reloading, chambering, or not holding M1
	if State.sprinting() or weaponState.reloading() or weaponState.chambering() then return end
	if not WC.holdingM1 or not WC.cycled then return end

	local freeLook = State.freeLook()
	local blocked = weaponState.blocked()
	local fireMode = weaponState.fireMode()

	local canFireShot = WC.canFire
		and not blocked
		and weaponState.holdStance() == Enums.HoldStance.Ready
		and WC.IsLoaded()
		and fireMode > 0
		and (config.fireWithFreelook or not freeLook)
		and not weaponState.equipping()

	if canFireShot then
		if not State.firstPerson() and not config.thirdPersonFiring then return end

		local currentStats = WC.GetCurrentWepStats()
		AnimationEvents.FireAnimRequested:Fire()
		WC.PerformRecoil(currentStats)

		WC.bulletsCurrentlyFired += 1
		WC.ejected = false

		if fireMode == Enums.FireModes.Semi or fireMode == Enums.FireModes.Manual or fireMode == Enums.FireModes.UBGL or (fireMode == Enums.FireModes.Burst and WC.bulletsCurrentlyFired >= currentStats.burstNumber) then
			WC.canFire = false
			WC.holdingM1 = false
		end
		
		WC.cycled = false
		local curModel = weaponState.gunModel()

		if fireMode ~= Enums.FireModes.Manual and fireMode ~= Enums.FireModes.UBGL then
			WC.EjectShell()
		end

		if fireMode ~= Enums.FireModes.UBGL then
			local bulletHandlerPart = ws.bulletHandler and weaponState.gunModel():FindFirstChild(ws.bulletHolder)
			if bulletHandlerPart then
				local bulletNumber = weaponState.gunAmmo.MagAmmo.MaxValue - (weaponState.gunAmmo.MagAmmo.Value - 1)
				local tempBulletPart = bulletHandlerPart:FindFirstChild("Bullet"..bulletNumber)
				if tempBulletPart then tempBulletPart.Transparency = 1 end
			end
		end

		local tempGunModel = weaponState.gunModel()
		if not State.firstPerson() then tempGunModel = WC.GetThirdPersonGunModel() end

		local muzzleName = (fireMode == Enums.FireModes.UBGL) and "UBGLMuzzle" or "Muzzle"
		local muCh = ws.muzzleChance
		local muzzleHost = findChildModelWithMainPartChild(tempGunModel, "Muzzle")
		if muzzleHost then
			tempGunModel = muzzleHost
		end

		bulletHandler.FireFX(WC.player, tempGunModel, muzzleName, muCh, fireMode == Enums.FireModes.UBGL)
		WC.PlayRepSound("Fire")

		if fireMode ~= Enums.FireModes.UBGL then
			WC.MoveBolt(currentStats.boltDist)
		end

		local shotCount = (currentStats.shotgun and currentStats.shotgunPellets) or 1
		for _ = 1, shotCount do
			local bulletOrigin, bulletDirection
		local tempSpread = weaponState.Spread * 100
			local spreadCFrame = CFrame.Angles(math.rad(math.random(-tempSpread, tempSpread) / 100), math.rad(math.random(-tempSpread, tempSpread) / 100), 0)

			local muzzlePoint = WC.GetMuzzlePoint(State.firstPerson() and curModel or WC.GetThirdPersonGunModel())
			bulletOrigin = muzzlePoint.WorldCFrame.Position
			bulletDirection = (muzzlePoint.WorldCFrame * spreadCFrame).LookVector

			local muVe = currentStats.muzzleVelocity
			local bulletVelocity = (bulletDirection * muVe * 3.5)

			local tracerColor = nil
			local TrTi = currentStats.tracerTiming
			if fireMode ~= Enums.FireModes.UBGL and currentStats.tracers and TrTi and weaponState.gunAmmo.MagAmmo.Value % TrTi == 0 then
				tracerColor = currentStats.tracerColor
			end

			local bulletData = State.equippedTool()
			if fireMode == Enums.FireModes.UBGL then
				bulletData = {
					Tool = State.equippedTool(),
					fireMode = fireMode,
					SPH_Weapon = State.equippedTool().SPH_Weapon
				}
			end

			bulletHandler.FireBullet(WC.thirdPersonRig, bulletOrigin, bulletDirection, bulletVelocity, bulletData, WC.player, tracerColor)
		end

		local firePoint = State.firstPerson() and WC.GetMuzzlePoint(curModel) or WC.GetMuzzlePoint(WC.GetThirdPersonGunModel())
		WC.playerFire:Fire(firePoint.WorldCFrame)

		local cycleTime = currentStats.fireRate
		if fireMode == Enums.FireModes.Burst and currentStats.burstFireRate then cycleTime = currentStats.burstFireRate end

		if currentStats.projectile ~= "Bullet" then
			WC.SetProjectileTransparency(weaponState.gunModel(), 1)
		end

		-- spread and recoil step
		weaponState.RecoilFactor = math.clamp(weaponState.RecoilFactor + ws.RecoilStepAmount,
			ws.MinRecoilFactor, ws.MaxRecoilFactor)

		local spreadStep = ws.SpreadStepAmount
		local minSpread = ws.MinSpread
		local maxSpread = ws.MaxSpread
		weaponState.Spread = math.clamp(math.max(weaponState.Spread, minSpread) + spreadStep, minSpread, maxSpread)

		task.wait(60 / cycleTime)
		if not State.equippedTool() then return end

		if currentStats.autoChamber and fireMode == Enums.FireModes.Manual and not weaponState.reloading() then
			weaponState.holdStance(Enums.HoldStance.Ready)
			weaponState.chambering(true)
		end
		WC.cycled = true
	else
		if not WC.IsLoaded() then
			if fireMode == Enums.FireModes.Manual and weaponState.gunAmmo.MagAmmo.Value > 0 then
				weaponState.holdStance(Enums.HoldStance.Ready)
				weaponState.chambering(true)
				WC.holdingM1 = false
			end
		elseif ws.emptyCloseBolt then
			WC.repChamber:Fire()
			WC.MoveBolt(CFrame.new())
		end
	end
end

function WC.UpdateRender(dt)
	local adjust = dt * 60
	if not State.equippedTool() or WC.camera.CameraType ~= Enum.CameraType.Custom then return end
	local ws = weaponState.wepStats()
	if not ws then
		return
	end

	--recoil logic
	weaponState.RecoilCF = weaponState.RecoilCF:Lerp(CFrame.new(),math.min(1, ws.PunchRecover * adjust))
	weaponState.RecoilPos.t = weaponState.RecoilCF.Position
	weaponState.RecoilDir.t = weaponState.RecoilCF.LookVector
	weaponState.RecoilUp.t = weaponState.RecoilCF.UpVector
	weaponState.RecoilFactor = math.clamp(weaponState.RecoilFactor - ws.RecoilRecoverPerSecond * dt,
		ws.MinRecoilFactor, ws.MaxRecoilFactor)

	local spreadRecover = ws.SpreadRecoverPerSecond
	local minSpread = ws.MinSpread
	local maxSpread = ws.MaxSpread
	weaponState.Spread = math.clamp(math.max(weaponState.Spread, minSpread) - (spreadRecover * dt), minSpread, maxSpread)

	local bipodPart = weaponState.gunModel().Grip:FindFirstChild("Bipod")
	local bipodModel = weaponState.gunModel()
	local bipMount = findChildModelWithMainPartChild(weaponState.gunModel(), "Bipod")
	if bipMount and bipMount.Main:FindFirstChild("Bipod") then
		bipodPart = bipMount.Main.Bipod
		bipodModel = bipMount
	end

	if bipodPart then
		local bipodRayParams = RaycastParams.new()
		bipodRayParams.FilterType = Enum.RaycastFilterType.Exclude
		bipodRayParams.FilterDescendantsInstances = WC.bipodRayIgnore
		bipodRayParams.RespectCanCollide = true
		local rayResult = workspace:Raycast(bipodPart.WorldCFrame.Position, Vector3.new(0,-1.5,0), bipodRayParams)
		WC.canBipod = rayResult ~= nil

		if WC.canBipod ~= weaponState.bipodEnabled() then
			weaponState.bipodEnabled(WC.canBipod)
		end
	end

	WC.holosightMod:UpdateRender(dt)
end

function WC.OnKeyframeReached(animName, keyframeName, newAnim, animType)
	local ws = weaponState.wepStats()
	if not ws then
		return
	end
	if weaponState.gunModel().Grip:FindFirstChild(keyframeName) then WC.PlayRepSound(keyframeName) end
	if keyframeName == "MagIn" then
		if State.equippedTool() and (not State.equippedTool().Chambered.Value or ws.openBolt) and ws.autoChamber then
			weaponState.reloading(true)
			AnimationEvents.StopAnimationRequested:Fire(animName, 0.4)
			AnimationEvents.BoltActionRequested:Fire(State.equippedTool().BoltReady.Value)
		end
		local bulletHandlerPart = ws.bulletHandler and weaponState.gunModel():FindFirstChild(ws.bulletHolder)
		if bulletHandlerPart then
			for _, child in bulletHandlerPart:GetChildren() do
				if child:IsA("BasePart") and string.sub(child.Name, 1, 6) == "Bullet" then child.Transparency = 0 end
			end
		end
		WC.repReload:Fire()
		if ws.magType > 1 then newAnim.DidLoop:Once(function() AnimationEvents.StopAnimationRequested:Fire(animName) end) end
	elseif keyframeName == "ShellInsert" or keyframeName == "BulletInsert" then
		if WC.cancelReload then
			WC.cancelReload = false
			newAnim.Looped = false
			newAnim.Stopped:Once(function()
				if not State.equippedTool() then return end
				AnimationEvents.StopAnimationRequested:Fire(newAnim.Name)
				if not State.equippedTool().BoltReady.Value or ws.openBolt then
					AnimationEvents.BoltActionRequested:Fire(false)
				else
					weaponState.reloading(false)
				end
			end)
		elseif weaponState.gunAmmo.MagAmmo.Value + 1 >= weaponState.gunAmmo.MagAmmo.MaxValue or weaponState.gunAmmo.ArcadeAmmoPool.Value - 1 <= 0 then
			newAnim.DidLoop:Once(function()
				if not State.equippedTool() then return end
				AnimationEvents.StopAnimationRequested:Fire(newAnim.Name)
				if not State.equippedTool().BoltReady.Value or ws.operationType == 3 or ws.openBolt then
					AnimationEvents.BoltActionRequested:Fire(false)
				else
					weaponState.reloading(false)
				end
			end)
		end
		local bulletHandlerPart = ws.bulletHolder and weaponState.gunModel():FindFirstChild(ws.bulletHolder)
		if bulletHandlerPart then
			local bulletNumber = weaponState.gunAmmo.MagAmmo.MaxValue - weaponState.gunAmmo.MagAmmo.Value
			local tempBulletPart = bulletHandlerPart:FindFirstChild("Bullet"..bulletNumber)
			if tempBulletPart then tempBulletPart.Transparency = 0 end
		end
		WC.repReload:Fire()
	elseif keyframeName == "ClipInsertEnd" then
		local ammoNeeded = weaponState.gunAmmo.MagAmmo.MaxValue - weaponState.gunAmmo.MagAmmo.Value
		local clipSize = ws.clipSize or ws.magazineCapacity
		if ammoNeeded > 0 then
			AnimationEvents.StopAnimationRequested:Fire(newAnim.Name)
			AnimationEvents.ReloadActionRequested:Fire(ammoNeeded >= clipSize)
		end
	elseif keyframeName == "ClipInsert" then
		WC.repReload:Fire()
	elseif keyframeName == "SlideRelease" or keyframeName == "BoltClose" then
		WC.repChamber:Fire()
		weaponState.reloading(false)
		WC.MoveBolt(CFrame.new(), true)
	elseif keyframeName == "SlidePull" and State.equippedTool() and State.equippedTool().Chambered.Value then
		WC.EjectShell()
	elseif keyframeName == "Switch" and not weaponState.reloading() then
		WC.SwitchFireMode()
	elseif keyframeName == "MagGrab" then
		WC.SetProjectileTransparency(weaponState.gunModel(), 0)
		WC.SetProjectileTransparency(WC.GetThirdPersonGunModel(), 0)
		WC.magGrab:Fire()
	elseif keyframeName == "BoltOpen" then
		WC.repBoltOpen:Fire()
		if not WC.ejected then WC.EjectShell() end
	end
end

function WC.OnAnimationStopped(animName, newAnim, animType)
	if animType == "Reload" then
		weaponState.reloading(false)
		if State.equippedTool() and State.equippedTool().Chambered.Value then
			WC.SetProjectileTransparency(weaponState.gunModel(), 0)
		end
	end
end

return WC
