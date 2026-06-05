local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")
local Charm = require(Packages.Charm)
local Framework = ReplicatedStorage.SPH_Framework
local Access = require(Framework.Access)
local assets = Access.assets
local config = Access.config
local Enums = require(Framework.Core.Enums)
local bulletHandler = require(Framework.Ballistics.BulletHandler)
local shellEjection = require(Framework.Weapons.ShellEjection)
local weldMod = require(Framework.Weapons.WeldMod)
local NetworkEvents = require(Framework.Network.NetworkEvents)
local LocalEvents = require(script.Parent.LocalEvents)
local weaponPrefsClient = require(Framework.Weapons.WeaponPrefsClient)
local weaponStatLocator = require(Framework.Weapons.WeaponStatLocator)
local holosightMod = require(Framework.Weapons.Mods.Holosight)

local RecoilModule = require(Framework.Weapons.Recoil.Default)

local CharacterStateModule = require(Framework.State.CharacterState)
local WeaponStateModule = require(Framework.State.WeaponState)

local STORAGE_CFRAME = CFrame.new(1000000, 0, 0)

local WeaponController = {}
WeaponController.__index = WeaponController

type self = {
	state: CharacterStateModule.CharacterState,
	weaponState: WeaponStateModule.WeaponState,
	events: LocalEvents.LocalEvents,

	holdingM1: boolean,
	cycled: boolean,
	canFire: boolean,
	canBipod: boolean,
	bipodRayIgnore: { Instance },
	ejected: boolean,
	cancelReload: boolean,
	bulletsCurrentlyFired: number,
	ubglAmmo: IntValue?,
	sights: { Instance },
	lastGunModel: Instance?,
	player: Player,
	character: Model,
	humanoid: Humanoid,
	humanoidRootPart: BasePart,
	camera: Camera,
	viewmodelRig: Model,
	thirdPersonRig: Model,
	holosightMod: any,
}

export type WeaponController = typeof(setmetatable({} :: self, WeaponController))

local P = NetworkEvents.packets

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

function WeaponController._applyPersistedWeaponPrefs(self: WeaponController, weaponName: string)
	weaponPrefsClient.applyPersisted(weaponName, self.state, self.weaponState, self)
end

function WeaponController.new(params: {
	player: Player,
	character: Model,
	humanoid: Humanoid,
	humanoidRootPart: BasePart,
	camera: Camera,
	viewmodelRig: Model,
	thirdPersonRig: Model,
	weaponState: WeaponStateModule.WeaponState,
	state: CharacterStateModule.CharacterState,
	events: LocalEvents.LocalEvents,
}): WeaponController
	local self = setmetatable({
		state = params.state,
		weaponState = params.weaponState,
		holdingM1 = false,
		cycled = true,
		canFire = true,
		canBipod = false,
		bipodRayIgnore = { params.character },
		ejected = true,
		cancelReload = false,
		bulletsCurrentlyFired = 0,
		ubglAmmo = nil,
		sights = {},
		lastGunModel = nil,
		player = params.player,
		character = params.character,
		humanoid = params.humanoid,
		humanoidRootPart = params.humanoidRootPart,
		camera = params.camera,
		viewmodelRig = params.viewmodelRig,
		thirdPersonRig = params.thirdPersonRig,
		holosightMod = holosightMod.new(params.weaponState),
		events = params.events,
	} :: self, WeaponController)

	self.character.ChildAdded:Connect(function(child)
		self:Equip(child)
	end)

	self.character.ChildRemoved:Connect(function(child)
		if self.state.equippedTool() and child == self.state.equippedTool() then
			self:Unequip(child)
		end
	end)

	Charm.subscribe(self.state.aiming, function(aiming)
		self:SyncAiming(aiming)
	end)
	Charm.subscribe(self.state.firstPerson, function(isFirstPerson)
		self:SyncFirstPerson(isFirstPerson)
	end)
	Charm.subscribe(self.state.sprinting, function(sprinting)
		self:SyncSprinting(sprinting)
	end)

	Charm.subscribe(self.weaponState.sightIndex, function(index)
		self:SyncSightIndex(index)
	end)
	Charm.subscribe(self.weaponState.flashlightEnabled, function(enabled)
		self:SyncFlashlightEnabled(enabled)
	end)
	Charm.subscribe(self.weaponState.bipodEnabled, function(enabled)
		self:SyncBipodEnabled(enabled)
	end)
	Charm.subscribe(self.weaponState.fireMode, function(mode)
		self:SyncFireMode(mode)
	end)
	Charm.subscribe(self.weaponState.chambering, function(chambering)
		self:SyncChambering(chambering)
	end)

	self.events.KeyframeReached:Connect(function(animName, keyframeName, newAnim, animType)
		self:OnKeyframeReached(animName, keyframeName, newAnim, animType)
	end)
	self.events.AnimationStopped:Connect(function(animName, newAnim, animType)
		self:OnAnimationStopped(animName, newAnim, animType)
	end)

	return self
end

function WeaponController.UpdateAttachmentsVisibility(self: WeaponController)
	if not self.state.equippedTool() then return end
	
	local isFirstPerson = self.state.firstPerson()
	local flashlightOn = self.weaponState.flashlightEnabled()
	local tpModel = self:GetThirdPersonGunModel()
	
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
	
	updateLight(self.weaponState.gunModel(), flashlightOn and isFirstPerson)
	updateLight(tpModel, flashlightOn and not isFirstPerson)
end

function WeaponController.SyncFlashlightEnabled(self: WeaponController, enabled)
	if not self.state.equippedTool() then return end
	if weaponPrefsClient.isApplying then
		self:UpdateAttachmentsVisibility()
		return
	end
	self:PlayRepSound("Button")
		P.PlayerToggleAttachment.send({ attachmentType = 0, enabled = enabled })
	self:UpdateAttachmentsVisibility()
end

function WeaponController.SyncBipodEnabled(self: WeaponController, enabled)
	if not self.state.equippedTool() then return end
	local bipodModel = self.weaponState.gunModel()
	local bipMount = findChildModelWithMainPartChild(self.weaponState.gunModel(), "Bipod")
	if bipMount then
		bipodModel = bipMount
	end
	if bipodModel then
		self:ToggleBipod(bipodModel, enabled)
		if weaponPrefsClient.isApplying then
			return
		end
		self:PlayRepSound("Switch")
		P.PlayerToggleAttachment.send({ attachmentType = 2, enabled = enabled })
	end
end

function WeaponController.SyncFireMode(self: WeaponController, mode)
	if not self.state.equippedTool() then return end
	if weaponPrefsClient.isApplying then
		return
	end
		P.SwitchFireMode.send({ mode = mode })
end


function WeaponController.SyncAiming(self: WeaponController, aiming)
	if aiming then
		-- effects n stuff
		local ADSMeshEnabled = self.weaponState.adsMeshEnabledForActiveSight()
		self:PlayRepSound("AimUp")
		self:ToggleADSMesh(ADSMeshEnabled)


		-- ready the character
		self.state.sprinting(false)
		self.weaponState.holdStance(Enums.HoldStance.Ready)
	else
		self:PlayRepSound("AimDown")
		self:ToggleADSMesh(false)

	end
end

function WeaponController.SyncFirstPerson(self: WeaponController, isFirstPerson)
	self:UpdateAttachmentsVisibility()
end

function WeaponController.SyncSprinting(self: WeaponController, sprinting)
	if sprinting then
		self.state.aiming(false)
		self.weaponState.holdStance(Enums.HoldStance.Ready)
		self.holdingM1 = false
	end
end

function WeaponController.SyncSightIndex(self: WeaponController, index)
	if self.weaponState:ADSMeshLayerEnabled(index) then
		self:ToggleADSMesh(true)
	else
		self:ToggleADSMesh(false)
	end
end



function WeaponController.PlayRepSound(self: WeaponController, soundName)
	local ws = self.weaponState.wepStats()
	if not self.state.dead() and ws then
		local soundToPlay
		local gm = self.weaponState.gunModel()
		if self.weaponState.ubglActive() then
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

		if soundToPlay and self.state.equippedTool() then
			if self.state.firstPerson() then
				soundToPlay:Play()
			else
				local clonedSound = soundToPlay:Clone()
				clonedSound.Parent = self.humanoidRootPart
				clonedSound:Play()
				Debris:AddItem(clonedSound, clonedSound.TimeLength)
			end
			P.PlaySound.send({ soundName = soundName, firstPerson = self.state.firstPerson() })
		end
	end
end

function WeaponController.GetCurrentWepStats(self: WeaponController)
	if self.weaponState.ubglActive() then
		local ws = self.weaponState.wepStats()
		return ws and ws.getStatsForMode(4)
	else
		return self.weaponState.wepStats()
	end
end

function WeaponController.IsLoaded(self: WeaponController)
	local currentStats = self:GetCurrentWepStats()
	if self.weaponState.ubglActive() then
		return self.ubglAmmo and self.ubglAmmo.Value > 0
	else
		return not currentStats.openBolt and self.state.equippedTool().Chambered.Value or currentStats.openBolt and self.weaponState.gunAmmo.MagAmmo.Value > 0
	end
end

function WeaponController.GetMuzzlePoint(self: WeaponController, gunModel)
	if self.weaponState.ubglActive() then
		local ubglMuzzle = gunModel.Grip:FindFirstChild("UBGLMuzzle")
		if ubglMuzzle then return ubglMuzzle end
	end
	return gunModel.Grip.Muzzle
end

function WeaponController.MoveBolt(self: WeaponController, direction:CFrame, silent:boolean)
	local ws = self.weaponState.wepStats()
	bulletHandler.MoveBolt(self.weaponState.gunModel(), ws, direction, self.weaponState.gunAmmo.MagAmmo.Value)
	bulletHandler.MoveBolt(self.thirdPersonRig.Weapon:FindFirstChildWhichIsA("Model"), ws, direction, self.weaponState.gunAmmo.MagAmmo.Value)
	if self.weaponState.gunAmmo.MagAmmo.Value <= 0 and not silent then
		self:PlayRepSound("Empty")
	end
		P.MoveBolt.send({
			direction = direction,
			magAmmo = self.weaponState.gunAmmo.MagAmmo.Value
		})
end

function WeaponController.ToggleADSMesh(self: WeaponController, toggle)
	if not self.weaponState.hasAdsMeshLayers() then
		return
	end

	--local ws = self.weaponState.wepStats()
	--local aimingTime = (ws and ws.aimTime and ws.aimTime / 20) or 0.2

	for _, child in ipairs(self.weaponState.gunModel():GetDescendants()) do
		if child.Name == "REG" then
			child.Transparency = toggle and (child:GetAttribute("TransparencyOverride") or 1) or 0
		elseif child.Name == "ADS" then
			child.Transparency = toggle and 0 or 1
		end
	end
end

function WeaponController.ToggleBipod(self: WeaponController, bipodModel, toggle)
	for _, bipObject in ipairs(bipodModel:GetChildren()) do
		if bipObject.Name == "Bipod_On" then
			bipObject.Transparency = toggle and 0 or 1
		elseif bipObject.Name == "Bipod_Off" then
			bipObject.Transparency = toggle and 1 or 0
		end
	end
end

function WeaponController.SetProjectileTransparency(self: WeaponController, model, transparency)
	local ws = self.weaponState.wepStats()
	if not ws or ws.projectile == "Bullet" or not model then return end
	local projectile = model:FindFirstChild(ws.projectile)
	if projectile then
		projectile.LocalTransparencyModifier = transparency
		for _, child in ipairs(projectile:GetDescendants()) do
			if child:IsA("BasePart") then child.LocalTransparencyModifier = transparency end
		end
	end
end

function WeaponController.EjectShell(self: WeaponController)
	self.ejected = true
	local ws = self.weaponState.wepStats()
	if ws and ws.shellEject then
		if self.state.firstPerson() then
			shellEjection.ejectShell(self.player, self.state.equippedTool(), self.weaponState.gunModel())
		else
			shellEjection.ejectShell(self.player, self.state.equippedTool(), self.thirdPersonRig.Weapon:FindFirstChildWhichIsA("Model"))
		end
	end
end

function WeaponController.GetThirdPersonGunModel(self: WeaponController)
	return self.thirdPersonRig.Weapon:FindFirstChildWhichIsA("Model")
end

function WeaponController.SwitchFireMode(self: WeaponController)
	local mode = self.weaponState.fireMode()
	local ws = self.weaponState.wepStats()
	if not ws then
		return
	end
	repeat
		mode += 1
		if mode > 5 then
			mode = 0
			break
		end
	until ws.fireSwitch[mode]
	self.weaponState.fireMode(mode)
end


function WeaponController.Unequip(self: WeaponController, tool)
	self.weaponState.equipped(false)
	self.weaponState.equipping(false)
	self.viewmodelRig.AnimBase.CFrame = STORAGE_CFRAME
	self.lastGunModel = self.weaponState.gunModel()
	
		P.SwitchWeapon.send({ tool = nil })
	if tool == self.state.equippedTool() then
		weaponPrefsClient.set(tool.Name, {
			laserEnabled = self.weaponState.laserEnabled(),
			flashlightEnabled = self.weaponState.flashlightEnabled(),
			bipodEnabled = self.weaponState.bipodEnabled(),
			fireMode = self.weaponState.fireMode(),
			sightIndex = self.weaponState.sightIndex(),
		})
		self.state.equippedTool(nil)
		self.weaponState:Reset()
	end
	UserInputService.MouseIconEnabled = true
	self.events.StopAllRequested:Fire()



	self.sights = {}
end

function WeaponController.Equip(self: WeaponController, newChild)
	if
		not newChild:FindFirstChild("SPH_Weapon")
		or (newChild:FindFirstChild("SPH_Weapon") and not assets.WeaponModels:FindFirstChild(newChild.Name))
		or self.state.dead()
		or (self.humanoid.Sit and not self.state.vehicleSeated())
	then
		return
	end

	UserInputService.MouseIconEnabled = false

	self.weaponState:Reset()
	self.weaponState.equipping(true)

	self.state.equippedTool(newChild)
	self.weaponState.wepStats(weaponStatLocator.getWeaponStats(self.state.equippedTool().SPH_Weapon))

	self.cycled = true
		P.SwitchWeapon.send({ tool = newChild })


	local ws = self.weaponState.wepStats()
	if ws and ws.PunchSpeed then
		self.weaponState.RecoilPos.s = ws.PunchSpeed
		self.weaponState.RecoilDir.s = ws.PunchSpeed
		self.weaponState.RecoilUp.s = ws.PunchSpeed
	end
	if ws and ws.PunchDamper then
		self.weaponState.RecoilPos.d = ws.PunchDamper
		self.weaponState.RecoilDir.d = ws.PunchDamper
		self.weaponState.RecoilUp.d = ws.PunchDamper
	end

	self.weaponState.RecoilFactor = ws and ws.MinRecoilFactor or 1
	-- fallbacks
	if ws and (not ws.operationType or type(ws.operationType) == "string") then
		ws.operationType = 1
	end
	if ws and not ws.magType then
		ws.magType = 1
	end

	local oldGun = self.viewmodelRig.Weapon:FindFirstChildWhichIsA("Model")
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
		if part.Name == "SightReticle" then table.insert(self.sights, part) end
	end

	gun.Parent = self.viewmodelRig.Weapon
	self.weaponState.gunModel(gun)

	self.weaponState.maid:GiveTask(weldMod.BlankM6D(self.viewmodelRig.AnimBase, gun.Grip))

	self.events.WeaponEquipRequested:Fire()
	self.events.WeaponIdleRequested:Fire()

	if not ws then return end
	if ws.openBolt or not self.state.equippedTool().Chambered.Value then
		self:SetProjectileTransparency(self.weaponState.gunModel(), 1)
	end

	self.weaponState.gunAmmo = self.state.equippedTool():WaitForChild("Ammo")
	self.weaponState.localAmmo(self.weaponState.gunAmmo.MagAmmo.Value)
	if ws.hasUBGL then
		self.ubglAmmo = newChild:FindFirstChild("UBGLAmmo")
		local ubglAmmoPool = newChild:FindFirstChild("UBGLAmmoPool")
		if not self.ubglAmmo then
			self.ubglAmmo = Instance.new("IntValue", newChild)
			self.ubglAmmo.Name = "UBGLAmmo"
			local totalStartAmmo = ws.ubgl.startAmmoPool or 6
			self.ubglAmmo.Value = (totalStartAmmo > 0 and (not ubglAmmoPool or ubglAmmoPool.Value > 0)) and 1 or 0
		end
		if not ubglAmmoPool then
			ubglAmmoPool = Instance.new("DoubleConstrainedValue", newChild)
			ubglAmmoPool.Name = "UBGLAmmoPool"
			ubglAmmoPool.MaxValue = ws.ubgl.maxAmmoPool or 12
			local totalStartAmmo = ws.ubgl.startAmmoPool or 6
			ubglAmmoPool.Value = totalStartAmmo > 0 and (totalStartAmmo - self.ubglAmmo.Value) or 0
		end

		if ws.ubgl.reloadAnim then
			local animSpeed = ws.reloadSpeedModifier
			self.events.PlayAnimationRequested:Fire(ws.ubgl.reloadAnim, { speed = animSpeed, transSpeed = 0.17 }, Enums.WeaponAnim.Reload)
		end
	else
		self.ubglAmmo = nil
	end

	if not self.state.equippedTool().BoltReady.Value then
		self:MoveBolt(ws.boltDist, true)
	end

	self.weaponState.fireMode(self.state.equippedTool().FireMode.Value)
	self.weaponState.holdStance(Enums.HoldStance.Ready)

	self:_applyPersistedWeaponPrefs(newChild.Name)
	self.weaponState.equipped(true)

	task.delay(1, function() self.lastGunModel = newChild end)
end

function WeaponController.OnTriggerIntent(self: WeaponController, inputState, inputObject)
	local inputBegan = Enum.UserInputState.Begin
	if inputState == inputBegan then
		self.cancelReload = true
		if not (self.state.sprinting() or self.weaponState.reloading()) then
			self.holdingM1 = true
			if not self:IsLoaded() and not (self.state.equippedTool():GetAttribute("FireMode") == Enums.FireModes.Manual and self.state.equippedTool():GetAttribute("MagAmmo") > 0) then
				self:PlayRepSound("Click")
			end
		end
	else
		self.holdingM1 = false
		self.canFire = true
		self.bulletsCurrentlyFired = 0
	end
end

function WeaponController.OnDropGunIntent(self: WeaponController, inputState, inputObject)
	local inputBegan = Enum.UserInputState.Begin
	if inputState == inputBegan then
		self:Unequip(self.state.equippedTool())
		P.PlayerDropGun.send({ _ = 0 })
	end
end

function WeaponController.OnReloadIntent(self: WeaponController, inputState, inputObject)
	local inputBegan = Enum.UserInputState.Begin
	if inputState ~= inputBegan or not self.weaponState.canManipulate() or not self.cycled then return end
	self.weaponState.holdStance(Enums.HoldStance.Ready)
	self.state.aiming(false)
	if self.weaponState.ubglActive() then
		local ubglAmmoPool = self.state.equippedTool():FindFirstChild("UBGLAmmoPool")
		if self.ubglAmmo and self.ubglAmmo.Value == 0 and ubglAmmoPool and ubglAmmoPool.Value > 0 then
			self.cancelReload = false
			self.events.ReloadRequested:Fire(self.lastGunModel and self.lastGunModel.Name)
		end
	else
		local ws = self.weaponState.wepStats()
		if not ws then
			return
		end
		if ws.infiniteAmmo or self.weaponState.gunAmmo.ArcadeAmmoPool.Value > 0 then
			if (ws.openBolt and self.weaponState.gunAmmo.MagAmmo.Value < self.weaponState.gunAmmo.MagAmmo.MaxValue) then
				self.cancelReload = false
				self.events.ReloadRequested:Fire(self.lastGunModel and self.lastGunModel.Name)
			else
				if (ws.operationType == Enums.OperationType.NonReciprocating and self.state.equippedTool().Chambered.Value)
					or (ws.operationType == Enums.OperationType.ManualCycleAlways and self.weaponState.gunAmmo.MagAmmo.Value + 1 >= self.weaponState.gunAmmo.MagAmmo.MaxValue)
					or (ws.operationType == Enums.OperationType.OpenBoltOnEmpty and self.weaponState.gunAmmo.MagAmmo.Value >= self.weaponState.gunAmmo.MagAmmo.MaxValue) then
						return
				end
				self.cancelReload = false
				self.events.ReloadRequested:Fire(self.lastGunModel and self.lastGunModel.Name)
			end
		end
	end
	
end

function WeaponController.OnChamberIntent(self: WeaponController, inputState, inputObject)
	local inputBegan = Enum.UserInputState.Begin
	if inputState == inputBegan and self.weaponState.canManipulate() and self.cycled then
		self.weaponState.chambering(true)
	end
end

function WeaponController.SyncChambering(self: WeaponController, chambering)
	if chambering then
		self.weaponState.holdStance(Enums.HoldStance.Ready)
		self.state.aiming(false)
	end
end

function WeaponController.OnSwitchSightsIntent(self: WeaponController, inputState, inputObject)
	local inputBegan = Enum.UserInputState.Begin
	if inputState == inputBegan and self.state.aiming() and self.weaponState.gunModel():FindFirstChild("AimPart2") then
		local tempIndex = self.weaponState.sightIndex() + 1
		if self.weaponState.gunModel():FindFirstChild("AimPart"..tempIndex) then
			self.weaponState.sightIndex(tempIndex)
			self:PlayRepSound("AimUp")
		else
			self.weaponState.sightIndex(1)
			self:PlayRepSound("AimDown")
		end
	end
end

function WeaponController.OnSwitchFireModeIntent(self: WeaponController, inputState, inputObject)
	local inputBegan = Enum.UserInputState.Begin
	if inputState == inputBegan then
		self.events.SwitchFireModeAnimRequested:Fire()
	end
end

function WeaponController.OnToggleFlashlightIntent(self: WeaponController, inputState, inputObject)
	local inputBegan = Enum.UserInputState.Begin
	if inputState == inputBegan then
		self.weaponState.flashlightEnabled(not self.weaponState.flashlightEnabled())
	end
end

function WeaponController.OnAimIntent(self: WeaponController, inputState, inputObject)
	local inputBegan = inputState == Enum.UserInputState.Begin
	if not UserInputService.TouchEnabled and not config.toggleAiming then -- Hold aiming
		if inputBegan
			and self.state.firstPerson()
			and not self.state.freeLook()
			and self.weaponState.canTrackAimInput() then
			self.weaponState.aimHeld(true)
			self.state.aiming(true)
		else
			self.weaponState.aimHeld(false)
			self.state.aiming(false)
		end
	elseif inputBegan then -- Mobile and toggle aiming
		if self.state.firstPerson()
		and not self.state.freeLook()
		and self.weaponState.canTrackAimInput()
		and not self.state.aiming() then
			self.weaponState.aimHeld(true)
			self.state.aiming(true)
		else
			self.weaponState.aimHeld(false)
			self.state.aiming(false)
		end
	end
end

function RANDF(Min, Max)
	return Min + math.random() * Max
end

function RAND2(mean,range)
	return (math.random()-0.5)*range + mean
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

local SP = require(Framework.Weapons.Spring.Default)

function WeaponController.PerformRecoil(self: WeaponController, wepStats)
	coroutine.wrap(function()
		local vr, hr, vP, hP, dP

		local VRecoil = RANDF(wepStats.VRecoil[1], wepStats.VRecoil[2])/1000
		local HRecoil = RANDF(wepStats.HRecoil[1], wepStats.HRecoil[2])/1000
		local finalRecoilPunch = wepStats.RecoilPunch
		
		-- if self.state.aiming() then
		-- 	VRecoil /= wepStats.AimRecoilReduction
		-- 	HRecoil /= wepStats.AimRecoilReduction
		-- end

		vr = RecoilCalc(VRecoil, wepStats.VRecoilDir, "Up") 
		hr = RecoilCalc(HRecoil, wepStats.HRecoilDir, "Side")

		vP = PunchCalc(wepStats.VPunchBase, wepStats.VPunchDir,"Up") 
		hP = PunchCalc(wepStats.HPunchBase, wepStats.HPunchDir,"Side")
		dP = PunchCalc(wepStats.DPunchBase, wepStats.DPunchDir,"Side")


		if self.state.aiming() then
			vr /= wepStats.AimRecoilReduction
			hr /= wepStats.AimRecoilReduction
			vP /= wepStats.AimRotationalPunchReduction
			hP /= wepStats.AimRotationalPunchReduction
			dP /= wepStats.AimRotationalPunchReduction
			finalRecoilPunch /= wepStats.AimBackwardPunchReduction
		end

		if self.weaponState.bipodEnabled() then
			vr  = vr/3
			hr = hr/3

			vP = vP*0.75

			hP = hP/2.5
			dP = dP/2.5

			self.weaponState.RecoilCF = RecoilModule.BipodRecoil(
				self.weaponState.RecoilCF, finalRecoilPunch, self.weaponState.RecoilFactor,vP,hP,dP)
		else
			self.weaponState.RecoilCF = RecoilModule.Recoil(
				self.weaponState.RecoilCF, finalRecoilPunch, self.weaponState.RecoilFactor,vP,hP,dP)
		end

		local recoilPower = self.weaponState.RecoilFactor
		vr *= recoilPower
		hr *= recoilPower

		self.weaponState.RecoilPos.t = self.weaponState.RecoilCF.Position
		self.weaponState.RecoilDir.t = self.weaponState.RecoilCF.LookVector
		self.weaponState.RecoilUp.t = self.weaponState.RecoilCF.UpVector
		
		self.weaponState.CameraSpring.t = self.weaponState.CameraSpring.t + Vector3.new(vr, hr, 0)
		self.weaponState.CameraSpring.p = self.weaponState.CameraSpring.p + Vector3.new(vr, hr, 0) * 0.5
		local duration = 0.25 --ServerConfig.AimRecoverDuration
		task.wait(duration/5 * self.weaponState.CameraSpring.s / SP.cs)
		--cwait(duration/5 * CameraSpring.s / SP.cs)
		local t = 0
		if wepStats.AimRecoverDuration then
			duration = wepStats.AimRecoverDuration
		end
		while t <= duration do
			local step = RunService.Heartbeat:Wait()
			t = t + step
			self.weaponState.CameraSpring.t = self.weaponState.CameraSpring.t - Vector3.new(vr, hr, 0) 
				* wepStats.AimRecover * step / duration
		end
	end)()
	
end



function WeaponController.UpdateHeartbeat(self: WeaponController, dt)
	if not self.state.equippedTool() or self.state.dead() then return end
	local ws = self.weaponState.wepStats()
	if not ws then
		return
	end
	
	-- General state checks: prevents execution if sprinting, reloading, chambering, or not holding M1
	if self.state.sprinting() or self.weaponState.reloading() or self.weaponState.chambering() then return end
	if not self.holdingM1 or not self.cycled then return end

	local freeLook = self.state.freeLook()
	local blocked = self.weaponState.blocked()
	local fireMode = self.weaponState.fireMode()

	local canFireShot = self.canFire
		and not blocked
		and self.weaponState.holdStance() == Enums.HoldStance.Ready
		and self:IsLoaded()
		and fireMode > 0
		and (config.fireWithFreelook or not freeLook)
		and not self.weaponState.equipping()

	if canFireShot then
		if not self.state.firstPerson() and not config.thirdPersonFiring then return end

		local currentStats = self:GetCurrentWepStats()
		self.weaponState.RecoilFactor = math.clamp(self.weaponState.RecoilFactor + ws.RecoilStepAmount,
			ws.MinRecoilFactor, ws.MaxRecoilFactor)

		self.events.FireAnimRequested:Fire()
		self:PerformRecoil(currentStats)

		self.bulletsCurrentlyFired += 1
		self.ejected = false

		if fireMode == Enums.FireModes.Semi or fireMode == Enums.FireModes.Manual or fireMode == Enums.FireModes.UBGL or (fireMode == Enums.FireModes.Burst and self.bulletsCurrentlyFired >= currentStats.burstNumber) then
			self.canFire = false
			self.holdingM1 = false
		end
		
		self.cycled = false
		local curModel = self.weaponState.gunModel()

		if fireMode ~= Enums.FireModes.Manual and fireMode ~= Enums.FireModes.UBGL then
			self:EjectShell()
		end

		if fireMode ~= Enums.FireModes.UBGL then
			local bulletHandlerPart = ws.bulletHandler and self.weaponState.gunModel():FindFirstChild(ws.bulletHolder)
			if bulletHandlerPart then
				local bulletNumber = self.weaponState.gunAmmo.MagAmmo.MaxValue - (self.weaponState.gunAmmo.MagAmmo.Value - 1)
				local tempBulletPart = bulletHandlerPart:FindFirstChild("Bullet"..bulletNumber)
				if tempBulletPart then tempBulletPart.Transparency = 1 end
			end
		end

		local tempGunModel = self.weaponState.gunModel()
		if not self.state.firstPerson() then tempGunModel = self:GetThirdPersonGunModel() end

		local muzzleName = (fireMode == Enums.FireModes.UBGL) and "UBGLMuzzle" or "Muzzle"
		local muCh = ws.muzzleChance
		local muzzleHost = findChildModelWithMainPartChild(tempGunModel, "Muzzle")
		if muzzleHost then
			tempGunModel = muzzleHost
		end

		bulletHandler.FireFX(self.player, tempGunModel, muzzleName, muCh, fireMode == Enums.FireModes.UBGL)
		self:PlayRepSound("Fire")

		if fireMode ~= Enums.FireModes.UBGL then
			self:MoveBolt(currentStats.boltDist)
		end

		local shotCount = (currentStats.shotgun and currentStats.shotgunPellets) or 1
		for _ = 1, shotCount do
			local bulletOrigin, bulletDirection
		local tempSpread = self.weaponState.Spread * 100
			local spreadCFrame = CFrame.Angles(math.rad(math.random(-tempSpread, tempSpread) / 100), math.rad(math.random(-tempSpread, tempSpread) / 100), 0)

			local muzzlePoint = self:GetMuzzlePoint(self.state.firstPerson() and curModel or self:GetThirdPersonGunModel())
			bulletOrigin = muzzlePoint.WorldCFrame.Position
			bulletDirection = (muzzlePoint.WorldCFrame * spreadCFrame).LookVector

			local muVe = currentStats.muzzleVelocity
			local bulletVelocity = (bulletDirection * muVe * 3.5)

			local tracerColor = nil
			local TrTi = currentStats.tracerTiming
			if fireMode ~= Enums.FireModes.UBGL and currentStats.tracers and TrTi and self.weaponState.gunAmmo.MagAmmo.Value % TrTi == 0 then
				tracerColor = currentStats.tracerColor
			end

			local bulletData = self.state.equippedTool()
			if fireMode == Enums.FireModes.UBGL then
				bulletData = {
					Tool = self.state.equippedTool(),
					fireMode = fireMode,
					SPH_Weapon = self.state.equippedTool().SPH_Weapon
				}
			end

			bulletHandler.FireBullet(self.thirdPersonRig, bulletOrigin, bulletDirection, bulletVelocity, bulletData, self.player, tracerColor, function(userData, raycastResult)
				-- when bullet hits, this callback lets other controllers know about it
				self.events.BulletHit:Fire(userData.wepStats, bulletOrigin, raycastResult)
			end)
		end

		local firePoint = self.state.firstPerson() and self:GetMuzzlePoint(curModel) or self:GetMuzzlePoint(self:GetThirdPersonGunModel())
		P.PlayerFire.send({ firePoint = firePoint.WorldCFrame })

		local cycleTime = currentStats.fireRate
		if fireMode == Enums.FireModes.Burst and currentStats.burstFireRate then cycleTime = currentStats.burstFireRate end

		if currentStats.projectile ~= "Bullet" then
			self:SetProjectileTransparency(self.weaponState.gunModel(), 1)
		end

		local spreadStep = ws.SpreadStepAmount
		local minSpread = ws.MinSpread
		local maxSpread = ws.MaxSpread
		self.weaponState.Spread = math.clamp(math.max(self.weaponState.Spread, minSpread) + spreadStep, minSpread, maxSpread)

		task.wait(60 / cycleTime)
		if not self.state.equippedTool() then return end

		if currentStats.autoChamber and fireMode == Enums.FireModes.Manual and not self.weaponState.reloading() then
			self.weaponState.holdStance(Enums.HoldStance.Ready)
			self.weaponState.chambering(true)
		end
		self.cycled = true
	else
		if not self:IsLoaded() then
			if fireMode == Enums.FireModes.Manual and self.weaponState.gunAmmo.MagAmmo.Value > 0 then
				self.weaponState.holdStance(Enums.HoldStance.Ready)
				self.weaponState.chambering(true)
				self.holdingM1 = false
			end
		elseif ws.emptyCloseBolt then
			P.PlayerChamber.send({ _ = 0 })
			self:MoveBolt(CFrame.new())
		end
	end
end

function WeaponController.UpdateRender(self: WeaponController, dt)
	local adjust = math.min(dt * 60, 2)
	if not self.state.equippedTool() or self.camera.CameraType ~= Enum.CameraType.Custom then return end
	local ws = self.weaponState.wepStats()
	if not ws then
		return
	end

	--recoil logic
	self.weaponState.RecoilCF = self.weaponState.RecoilCF:Lerp(CFrame.new(),math.min(1, ws.PunchRecover * adjust))
	self.weaponState.RecoilPos.t = self.weaponState.RecoilCF.Position
	self.weaponState.RecoilDir.t = self.weaponState.RecoilCF.LookVector
	self.weaponState.RecoilUp.t = self.weaponState.RecoilCF.UpVector
	self.weaponState.RecoilFactor = math.clamp(self.weaponState.RecoilFactor - ws.RecoilRecoverPerSecond * dt,
		ws.MinRecoilFactor, ws.MaxRecoilFactor)

	local spreadRecover = ws.SpreadRecoverPerSecond
	local minSpread = ws.MinSpread
	local maxSpread = ws.MaxSpread
	self.weaponState.Spread = math.clamp(math.max(self.weaponState.Spread, minSpread) - (spreadRecover * dt), minSpread, maxSpread)

	local bipodPart = self.weaponState.gunModel().Grip:FindFirstChild("Bipod")
	--local bipodModel = self.weaponState.gunModel()
	local bipMount = findChildModelWithMainPartChild(self.weaponState.gunModel(), "Bipod")
	if bipMount and bipMount.Main:FindFirstChild("Bipod") then
		bipodPart = bipMount.Main.Bipod
		--bipodModel = bipMount
	end

	if bipodPart then
		local bipodRayParams = RaycastParams.new()
		bipodRayParams.FilterType = Enum.RaycastFilterType.Exclude
		bipodRayParams.FilterDescendantsInstances = self.bipodRayIgnore
		bipodRayParams.RespectCanCollide = true
		local rayResult = workspace:Raycast(bipodPart.WorldCFrame.Position, Vector3.new(0,-1.5,0), bipodRayParams)
		self.canBipod = rayResult ~= nil

		if self.canBipod ~= self.weaponState.bipodEnabled() then
			self.weaponState.bipodEnabled(self.canBipod)
		end
	end

	self.holosightMod:UpdateRender(dt)
end

function WeaponController.OnKeyframeReached(self: WeaponController, animName, keyframeName, newAnim, animType)
	local ws = self.weaponState.wepStats()
	if not ws then
		return
	end
	if self.weaponState.gunModel().Grip:FindFirstChild(keyframeName) then self:PlayRepSound(keyframeName) end
	if keyframeName == "MagIn" then
		if self.state.equippedTool() and (not self.state.equippedTool().Chambered.Value or ws.openBolt) and ws.autoChamber then
			self.weaponState.reloading(true)
			self.events.StopAnimationRequested:Fire(animName, 0.4)
			self.events.BoltActionRequested:Fire(self.state.equippedTool().BoltReady.Value)
		end
		local bulletHandlerPart = ws.bulletHandler and self.weaponState.gunModel():FindFirstChild(ws.bulletHolder)
		if bulletHandlerPart then
			for _, child in bulletHandlerPart:GetChildren() do
				if child:IsA("BasePart") and string.sub(child.Name, 1, 6) == "Bullet" then child.Transparency = 0 end
			end
		end
		P.Reload.send({ _ = 0 })
		if ws.magType > 1 then newAnim.DidLoop:Once(function() self.events.StopAnimationRequested:Fire(animName) end) end
	elseif keyframeName == "ShellInsert" or keyframeName == "BulletInsert" then
		if self.cancelReload then
			self.cancelReload = false
			newAnim.Looped = false
			newAnim.Stopped:Once(function()
				if not self.state.equippedTool() then return end
				self.events.StopAnimationRequested:Fire(newAnim.Name)
				if not self.state.equippedTool().BoltReady.Value or ws.openBolt then
					self.events.BoltActionRequested:Fire(false)
				else
					self.weaponState.reloading(false)
				end
			end)
		elseif self.weaponState.gunAmmo.MagAmmo.Value + 1 >= self.weaponState.gunAmmo.MagAmmo.MaxValue or self.weaponState.gunAmmo.ArcadeAmmoPool.Value - 1 <= 0 then
			newAnim.DidLoop:Once(function()
				if not self.state.equippedTool() then return end
				self.events.StopAnimationRequested:Fire(newAnim.Name)
				if not self.state.equippedTool().BoltReady.Value or ws.operationType == 3 or ws.openBolt then
					self.events.BoltActionRequested:Fire(false)
				else
					self.weaponState.reloading(false)
				end
			end)
		end
		local bulletHandlerPart = ws.bulletHolder and self.weaponState.gunModel():FindFirstChild(ws.bulletHolder)
		if bulletHandlerPart then
			local bulletNumber = self.weaponState.gunAmmo.MagAmmo.MaxValue - self.weaponState.gunAmmo.MagAmmo.Value
			local tempBulletPart = bulletHandlerPart:FindFirstChild("Bullet"..bulletNumber)
			if tempBulletPart then tempBulletPart.Transparency = 0 end
		end
		P.Reload.send({ _ = 0 })
	elseif keyframeName == "ClipInsertEnd" then
		local ammoNeeded = self.weaponState.gunAmmo.MagAmmo.MaxValue - self.weaponState.gunAmmo.MagAmmo.Value
		local clipSize = ws.clipSize or ws.magazineCapacity
		if ammoNeeded > 0 then
			self.events.StopAnimationRequested:Fire(newAnim.Name)
			self.events.ReloadActionRequested:Fire(ammoNeeded >= clipSize)
		end
	elseif keyframeName == "ClipInsert" then
		P.Reload.send({ _ = 0 })
	elseif keyframeName == "SlideRelease" or keyframeName == "BoltClose" then
			P.PlayerChamber.send({ _ = 0 })
		self.weaponState.reloading(false)
		self:MoveBolt(CFrame.new(), true)
	elseif keyframeName == "SlidePull" and self.state.equippedTool() and self.state.equippedTool().Chambered.Value then
		self:EjectShell()
	elseif keyframeName == "Switch" and not self.weaponState.reloading() then
		self:SwitchFireMode()
	elseif keyframeName == "MagGrab" then
		self:SetProjectileTransparency(self.weaponState.gunModel(), 0)
		self:SetProjectileTransparency(self:GetThirdPersonGunModel(), 0)
		P.MagGrab.send({ _ = 0 })
	elseif keyframeName == "BoltOpen" then
		P.RepBoltOpen.send({ _ = 0 })
		if not self.ejected then self:EjectShell() end
	end
end

function WeaponController.OnAnimationStopped(self: WeaponController, animName, newAnim, animType)
	if animType == Enums.WeaponAnim.Reload.tag then
		self.weaponState.reloading(false)
		if self.state.equippedTool() and self.state.equippedTool().Chambered.Value then
			self:SetProjectileTransparency(self.weaponState.gunModel(), 0)
		end
	end
end

return WeaponController
