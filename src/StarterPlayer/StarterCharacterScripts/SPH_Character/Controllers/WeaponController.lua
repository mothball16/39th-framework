local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Charm = require(Packages.Charm)

local assets = ReplicatedStorage:WaitForChild("SPH_Assets")
local config = require(assets.GameConfig)
local modules = assets.Modules
local gunsmith = require(modules.Gunsmith)
local bulletHandler = require(modules.BulletHandler)
local shellEjection = require(modules.ShellEjection)
local weldMod = require(modules.WeldMod)
local bridgeNet = require(modules.BridgeNet)

local State = require(script.Parent.CharacterState)
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
	chambering = false,
	bulletsCurrentlyFired = 0,
	ubglAmmo = nil,
	sights = {},
	lastGunModel = nil,
	fireModes = { Safe = 0, Semi = 1, Auto = 2, Burst = 3, UBGL = 4, Manual = 5 },
	holdAnim = nil,

	-- Dependencies
	player = nil,
	character = nil,
	humanoid = nil,
	humanoidRootPart = nil,
	camera = nil,
	viewmodelRig = nil,
	thirdPersonRig = nil,
	rigType = nil,
	laserDotUI = nil,
	laserDotPoint = nil,
	laserBeamFP = nil,
	laserBeamTP = nil,

	AnimationController = nil,
	ViewmodelController = nil,
	MovementController = nil,
	InputController = nil,
	
	RefreshViewmodel = nil,
	ToggleAiming = nil,
}

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

function WC.Initialize(params)
	WC.player = params.player
	WC.character = params.character
	WC.humanoid = params.humanoid
	WC.humanoidRootPart = params.humanoidRootPart
	WC.camera = params.camera
	WC.viewmodelRig = params.viewmodelRig
	WC.thirdPersonRig = params.thirdPersonRig
	WC.rigType = params.rigType
	
	WC.laserDotUI = params.laserDotUI
	WC.laserDotPoint = params.laserDotPoint
	WC.laserBeamFP = params.laserBeamFP
	WC.laserBeamTP = params.laserBeamTP
	
	WC.bipodRayIgnore = {params.character}
	
	WC.AnimationController = params.AnimationController
	WC.ViewmodelController = params.ViewmodelController
	WC.MovementController = params.MovementController
	WC.InputController = params.InputController
	
	WC.RefreshViewmodel = params.RefreshViewmodel
	WC.ToggleAiming = params.ToggleAiming
	
	WC.character.ChildAdded:Connect(function(child)
		WC.Equip(child)
	end)
	
	WC.character.ChildRemoved:Connect(function(child)
		if State.equipped() and child == State.equipped() then
			WC.Unequip(child)
		end
	end)

	Charm.subscribe(State.aiming, WC.OnAimToggled)
	Charm.subscribe(State.sightIndex, WC.OnSightIndexSwitched)
	Charm.subscribe(State.firstPerson, WC.OnFirstPersonToggled)
	Charm.subscribe(State.sprinting, WC.OnSprintToggled)
	Charm.subscribe(State.laserEnabled, WC.OnLaserToggled)
	Charm.subscribe(State.flashlightEnabled, WC.OnFlashlightToggled)
	Charm.subscribe(State.bipodEnabled, WC.OnBipodToggled)
	Charm.subscribe(State.fireMode, WC.OnFireModeChanged)
	Charm.subscribe(State.holdStance, WC.OnHoldStanceChanged)
end

function WC.UpdateAttachmentsVisibility()
	if not State.equipped() then return end
	
	local isFirstPerson = State.firstPerson()
	local laserOn = State.laserEnabled()
	local flashlightOn = State.flashlightEnabled()
	local tpModel = WC.GetThirdPersonGunModel()
	
	if laserOn and config.laserTrail then
		WC.laserBeamFP.Enabled = isFirstPerson
		WC.laserBeamTP.Enabled = not isFirstPerson
		
		if not isFirstPerson and tpModel then
			if State.attStats.laserOrigin and State.gunModel[State.attStats.laserOrigin].Main:FindFirstChild("Laser") then
				WC.laserBeamTP.Attachment0 = tpModel[State.attStats.laserOrigin].Main.Laser
			elseif tpModel.Grip:FindFirstChild("Laser") then
				WC.laserBeamTP.Attachment0 = tpModel.Grip.Laser
			end
		end
	else
		WC.laserBeamFP.Enabled = false
		WC.laserBeamTP.Enabled = false
	end
	
	local function updateLight(model, enabled)
		if not model then return end
		if model.Grip:FindFirstChild("Flashlight") then
			local light = model.Grip.Flashlight:FindFirstChildWhichIsA("Light")
			if light then light.Enabled = enabled end
		end
		if State.attStats.flashlights_client then
			for _, lightAttachment in ipairs(State.attStats.flashlights_client) do
				if model:FindFirstChild(lightAttachment.Name) then
					local light = model[lightAttachment.Name].Main.Flashlight:FindFirstChildWhichIsA("Light")
					if light then light.Enabled = enabled end
				end
			end
		end
	end
	
	updateLight(State.gunModel, flashlightOn and isFirstPerson)
	updateLight(tpModel, flashlightOn and not isFirstPerson)
end

function WC.OnLaserToggled(enabled)
	if not State.equipped() then return end
	WC.PlayRepSound("Button")
	WC.playerToggleAttachment:Fire(1, enabled)
	
	WC.laserDotUI.Enabled = enabled
	if enabled then
		local lazerbeem = State.gunModel.Grip:FindFirstChild("Laser")
		if State.attStats.laserOrigin then lazerbeem = State.gunModel[State.attStats.laserOrigin].Main:FindFirstChild("Laser") end
		if lazerbeem then
			WC.laserDotUI.Dot.ImageColor3 = lazerbeem.Color.Value
			if config.laserTrail then
				WC.laserBeamFP.Color = ColorSequence.new(lazerbeem.Color.Value)
				WC.laserBeamTP.Color = ColorSequence.new(lazerbeem.Color.Value)
			end
		end
	end
	WC.UpdateAttachmentsVisibility()
end

function WC.OnFlashlightToggled(enabled)
	if not State.equipped() then return end
	WC.PlayRepSound("Button")
	WC.playerToggleAttachment:Fire(0, enabled)
	WC.UpdateAttachmentsVisibility()
end

function WC.OnBipodToggled(enabled)
	if not State.equipped() then return end
	local bipodModel = State.gunModel
	if State.attStats.Bipod and State.gunModel[State.attStats.Bipod].Main:FindFirstChild("Bipod") then
		bipodModel = State.gunModel[State.attStats.Bipod]
	end
	if bipodModel then
		WC.ToggleBipod(bipodModel, enabled)
		WC.PlayRepSound("Switch")
		WC.playerToggleAttachment:Fire(2, enabled)
	end
end

function WC.OnFireModeChanged(mode)
	if not State.equipped() then return end
	WC.switchFireMode:Fire(mode)
end


function WC._adsMeshEnabled(sightIndex)
	return (State.attStats and State.attStats.ADSEnabled and State.attStats.ADSEnabled[sightIndex])
	or (State.wepStats and State.wepStats.ADSEnabled and State.wepStats.ADSEnabled[sightIndex])
end


function WC.OnAimToggled(aiming)
	if aiming then
		WC.ChangeHoldStance(0)
		local ADSMeshEnabled = WC._adsMeshEnabled(State.sightIndex())

		WC.PlayRepSound("AimUp")
		WC.ToggleADS(ADSMeshEnabled)

		if not config.lockFirstPerson then
			Player.CameraMode = Enum.CameraMode.LockFirstPerson
		end
	else
		WC.PlayRepSound("AimDown")
		UserInputService.MouseDeltaSensitivity = 1

		local aimOutTime = State.wepStats and State.wepStats.aimTime / 2 or 0.3

		TweenService:Create(Camera,TweenInfo.new(aimOutTime),{FieldOfView = config.defaultFOV}):Play()
		if not config.lockFirstPerson then
			Player.CameraMode = defaultCameraMode
		end
	end
end

function WC.OnFirstPersonToggled(isFirstPerson)
	if isFirstPerson then
		if State.equipped() then
			WC.InputController.BindAiming()
		end
	else
		WC.InputController.UnbindAiming()
	end
	WC.UpdateAttachmentsVisibility()
end

function WC.OnSprintToggled(sprinting)
	if sprinting then
		State.aiming(false)
		WC.holdingM1 = false
		WC.ChangeHoldStance(0)
	end
end

function WC.OnSightIndexSwitched(index)
	if WC._adsMeshEnabled(index) then
		WC.ToggleADS(true)
	else
		WC.ToggleADS(false)
	end
end



function WC.PlayRepSound(soundName)
	if not State.dead() and State.wepStats then
		local soundToPlay
		if State.fireMode() == WC.fireModes.UBGL and State.wepStats.hasUBGL then
			soundToPlay = State.gunModel.Grip:FindFirstChild("UBGL_" .. soundName)
			if not soundToPlay then
				soundToPlay = State.gunModel.Grip:FindFirstChild(soundName)
				if State.attStats.newFireSound and soundName == "Fire" then
					soundToPlay = State.gunModel[State.attStats.newMuzzleDevice].Main.Fire
				end
			end
		else
			soundToPlay = State.gunModel.Grip:FindFirstChild(soundName)
			if State.attStats.newFireSound and soundName == "Fire" then
				soundToPlay = State.gunModel[State.attStats.newMuzzleDevice].Main.Fire
			end
		end

		if soundToPlay and State.equipped() then
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
	if State.fireMode() == WC.fireModes.UBGL and State.wepStats.hasUBGL then
		return State.wepStats.getStatsForMode(4)
	else
		return State.wepStats
	end
end

function WC.IsLoaded()
	local currentStats = WC.GetCurrentWepStats()
	if State.fireMode() == WC.fireModes.UBGL and State.wepStats.hasUBGL then
		return WC.ubglAmmo and WC.ubglAmmo.Value > 0
	else
		return not currentStats.openBolt and State.equipped().Chambered.Value or currentStats.openBolt and State.gunAmmo.MagAmmo.Value > 0
	end
end

function WC.GetMuzzlePoint(gunModel)
	if State.fireMode() == WC.fireModes.UBGL and State.wepStats.hasUBGL then
		local ubglMuzzle = gunModel.Grip:FindFirstChild("UBGLMuzzle")
		if ubglMuzzle then return ubglMuzzle end
	end
	return gunModel.Grip.Muzzle
end

function WC.MoveBolt(direction:CFrame, silent:boolean)
	bulletHandler.MoveBolt(State.gunModel, State.wepStats, direction, State.gunAmmo.MagAmmo.Value)
	bulletHandler.MoveBolt(WC.thirdPersonRig.Weapon:FindFirstChildWhichIsA("Model"), State.wepStats, direction, State.gunAmmo.MagAmmo.Value)
	if State.gunAmmo.MagAmmo.Value <= 0 and not silent then
		WC.PlayRepSound("Empty")
	end
	WC.moveBolt:Fire(direction, State.gunAmmo.MagAmmo.Value)
end

function WC.ToggleADS(toggle)
	if not ((State.wepStats and State.wepStats.ADSEnabled) or (State.attStats and State.attStats.ADSEnabled)) then
		return
	end

	local aimingTime = (State.wepStats.aimTime and State.wepStats.aimTime / 20) or 0.2
	if State.attStats.aimTime then aimingTime *= State.attStats.aimTime end

	for _, child in ipairs(State.gunModel:GetDescendants()) do
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
	if not State.wepStats or State.wepStats.projectile == "Bullet" or not model then return end
	local projectile = model:FindFirstChild(State.wepStats.projectile)
	if projectile then
		projectile.LocalTransparencyModifier = transparency
		for _, child in ipairs(projectile:GetDescendants()) do
			if child:IsA("BasePart") then child.LocalTransparencyModifier = transparency end
		end
	end
end

function WC.EjectShell()
	WC.ejected = true
	if State.wepStats.shellEject then
		if State.firstPerson() then
			shellEjection.ejectShell(WC.player, State.equipped(), State.gunModel)
		else
			shellEjection.ejectShell(WC.player, State.equipped(), WC.thirdPersonRig.Weapon:FindFirstChildWhichIsA("Model"))
		end
	end
end

function WC.GetThirdPersonGunModel()
	return WC.thirdPersonRig.Weapon:FindFirstChildWhichIsA("Model")
end

function WC.SwitchFireMode()
	local mode = State.fireMode()
	repeat
		mode += 1
		if mode > 5 then mode = 0 break end
	until State.wepStats.fireSwitch[mode]
	State.fireMode(mode)
end

function WC.ChangeHoldStance(newStance)
	if State.aiming() then return end
	if State.holdStance() == newStance and WC.holdAnim then
		State.holdStance(0)
	else
		State.holdStance(newStance)
	end
end

function WC.OnHoldStanceChanged(newStance, oldStance)
	if WC.holdAnim then
		WC.AnimationController.StopAnimation(WC.holdAnim.Name, 0.3)
		WC.holdAnim = nil
	end

	if not State.equipped() then return end

	local animToPlay
	if newStance == 1 and State.wepStats.holdUpAnim then
		animToPlay = State.wepStats.holdUpAnim
	elseif newStance == 2 and State.wepStats.patrolAnim then
		animToPlay = State.wepStats.patrolAnim
	elseif newStance == 3 and State.wepStats.holdDownAnim then
		animToPlay = State.wepStats.holdDownAnim
	end

	if animToPlay then
		WC.holdAnim = WC.AnimationController.PlayAnimation(animToPlay, {looped = true, priority = Enum.AnimationPriority.Action, transSpeed = 0.3})
		if WC.holdAnim then WC.holdAnim:Play() end
	end
end

function WC.ChamberAnim()
	local animNameToPlay
	if State.equipped().BoltReady.Value or State.fireMode() == WC.fireModes.Manual then
		animNameToPlay = State.wepStats.boltChamber
	else
		animNameToPlay = State.wepStats.boltClose
	end

	if animNameToPlay then
		State.reloading(true)
		WC.chambering = true
		WC.ChangeHoldStance(0)
		local playingAnim:AnimationTrack = WC.AnimationController.PlayAnimation(animNameToPlay, {priority = Enum.AnimationPriority.Action2, transSpeed = 0.05})
		playingAnim.Stopped:Once(function()
			WC.chambering = false
		end)
	end
end

function WC.IdleAnim()
	WC.AnimationController.PlayAnimation(State.wepStats.idleAnim, {looped = true, priority = Enum.AnimationPriority.Idle})
end

function WC.EquipAnim()
	WC.AnimationController.PlayAnimation(State.wepStats.equipAnim, {priority = Enum.AnimationPriority.Action2}, "Equip")
	task.wait(0.1)
	
	if not State.wepStats then return end
	if State.wepStats.openBolt or not State.equipped().Chambered.Value then
		WC.SetProjectileTransparency(State.gunModel, 1)
	end
end

function WC.ReloadAnim()
	if not State.equipped() then return end
	WC.cancelReload = false
	WC.ChangeHoldStance(0)
	State.reloading(true)
	
	local animSpeed = State.wepStats.reloadSpeedModifier
	if State.attStats.reloadSpeedModifier then animSpeed *= State.attStats.reloadSpeedModifier end

	if State.fireMode() == WC.fireModes.UBGL and State.wepStats.hasUBGL then
		local ubglStats = State.wepStats.getStatsForMode(4)
		if ubglStats.reloadAnim then
			WC.AnimationController.PlayAnimation(ubglStats.reloadAnim, {speed = animSpeed, priority = Enum.AnimationPriority.Action2, transSpeed = 0.17}, "Reload")
		else
			WC.AnimationController.PlayAnimation(State.wepStats.reloadAnim, {speed = animSpeed, priority = Enum.AnimationPriority.Action2, transSpeed = 0.17}, "Reload")
		end
		return
	end

	if State.wepStats.operationType == 3 or (State.wepStats.operationType == 2 and State.gunAmmo.MagAmmo.Value <= 0 and not State.equipped().Chambered.Value) then
		local boltOpenTrack = WC.AnimationController.PlayAnimation(State.wepStats.boltOpen, {speed = animSpeed, priority = Enum.AnimationPriority.Action2, transSpeed = 0.17})
		if not boltOpenTrack then
			warn("To use operation type "..State.wepStats.operationType..", a 'boltOpen' animation is required.")
			State.reloading(false)
			return
		end
		boltOpenTrack.Stopped:Once(function()
			if State.wepStats.magType == 3
				and (State.gunAmmo.MagAmmo.MaxValue - State.gunAmmo.MagAmmo.Value) >= (State.wepStats.clipSize or State.attStats.magazineCapacity or State.wepStats.magazineCapacity)
				and State.gunAmmo.ArcadeAmmoPool.Value >= (State.wepStats.clipSize or State.attStats.magazineCapacity or State.wepStats.magazineCapacity) then
				
				WC.AnimationController.PlayAnimation(State.wepStats.clipReloadAnim, {looped = true, speed = animSpeed, priority = Enum.AnimationPriority.Action2, transSpeed = 0.17})
			else
				if WC.lastGunModel and WC.lastGunModel.Name ~= State.gunModel.Name then return end
				local bulletInsert = WC.AnimationController.PlayAnimation(State.wepStats.reloadAnim, {speed = animSpeed, priority = Enum.AnimationPriority.Action2, transSpeed = 0.17, looped = true}, "Reload")
				if State.wepStats.magType > 1 then bulletInsert.Looped = true end
			end
		end)
	else
		WC.AnimationController.PlayAnimation(State.wepStats.reloadAnim, {speed = animSpeed, priority = Enum.AnimationPriority.Action2, transSpeed = 0.17}, "Reload")
	end
end

function WC.Unequip(tool)
	State.equipping(false)
	WC.viewmodelRig.AnimBase.CFrame = storageCFrame
	WC.lastGunModel = State.gunModel
	
	WC.switchWeapon:Fire()
	if tool == State.equipped() then
		State.equipped(nil)
		State.wepStats = nil
		State.attStats = {}
	end
	UserInputService.MouseIconEnabled = true
	WC.ToggleAiming(false)
	WC.AnimationController.StopAll()

	if config.lockFirstPerson then
		WC.player.CameraMode = Enum.CameraMode.Classic
	end

	WC.sights = {}

	WC.holdAnim = nil
	State.laserEnabled(false)
	State.flashlightEnabled(false)
	State.bipodEnabled(false)
	State.holdStance(0)
	WC.laserDotUI.Enabled = false
	WC.laserBeamFP.Enabled = false
	WC.laserBeamTP.Enabled = false

	WC.InputController.UnbindGunInputs()
end

function WC.SetAttachment(weapon, attachmentSlot, weaponAttachment, parentPart)
	local newAttachment = gunsmith.placeAttachment(weapon, attachmentSlot, weaponAttachment, parentPart)
	if not assets.Attachments:FindFirstChild(weaponAttachment) then warn(weaponAttachment.." Not found!") return end
	
	local newAttStats = require(assets.Attachments[weaponAttachment].AttStats)
	if newAttStats.ADSEnabled then
		if not State.attStats.ADSEnabled then State.attStats.ADSEnabled = newAttStats.ADSEnabled end
	end

	for _, part in ipairs(newAttachment:GetChildren()) do
		if part.Name == "SightReticle" then
			table.insert(WC.sights, part)
		end
		if string.find(part.Name, "AimPart") then
			if not State.attStats.aimParts then State.attStats.aimParts = {} end
			if not State.attStats.aimParts[part.Name] then
				State.attStats.aimParts[part.Name] = newAttachment.Name
			else
				local newSightIndex = 1
				for _, _ in pairs(State.attStats.aimParts) do newSightIndex += 1 end
				part.Name = "AimPart"..newSightIndex
				State.attStats.aimParts[part.Name] = newAttachment.Name
			end
			if weapon:FindFirstChild(part.Name) then
				weapon.Grip["Grip_"..part.Name]:Destroy()
				weapon[part.Name].CFrame = part.CFrame
				weldMod.Weld(weapon[part.Name], weapon.Grip)
			end
		end
	end

	if newAttachment.Main:FindFirstChild("Flashlight") then
		if not State.attStats.flashlights_client then State.attStats.flashlights_client = {} end
		table.insert(State.attStats.flashlights_client, newAttachment)
	end

	weldMod.WeldModel(newAttachment, parentPart[attachmentSlot], false)
end

function WC.setRecursiveAttachments(weapon, attachmentSlot, weaponAttachment, parentPart)
	if not weaponAttachment or weaponAttachment == "" then return end
	if typeof(weaponAttachment) == "string" then
		if not parentPart:FindFirstChild(attachmentSlot) then return end
		WC.SetAttachment(weapon, attachmentSlot, weaponAttachment, parentPart)
	elseif typeof(weaponAttachment) == "table" then
		local subAttachment = weaponAttachment[1]
		local subAttachmentNodes = weaponAttachment[2]
		WC.SetAttachment(weapon, attachmentSlot, subAttachment, parentPart)
		for item, name in pairs(subAttachmentNodes) do
			WC.setRecursiveAttachments(weapon, item, name, weapon[subAttachment])
		end
	end
end

function WC.Equip(newChild)
	if newChild:FindFirstChild("SPH_Weapon") and not assets.WeaponModels:FindFirstChild(newChild.Name) then return end

	if newChild:FindFirstChild("SPH_Weapon") and not State.dead() and (not WC.humanoid.Sit or WC.humanoid.Sit and not WC.MovementController.vehicleSeated) then
		State.reloading(false)
		UserInputService.MouseIconEnabled = false
		WC.ViewmodelController.ResetHipRotation()
		State.equipping(true)
		State.laserEnabled(false)
		State.flashlightEnabled(false)
		State.bipodEnabled(false)
		WC.cycled = true
		WC.chambering = false

		WC.switchWeapon:Fire(newChild)

		State.equipped(newChild)
		State.wepStats = require(State.equipped().SPH_Weapon.WeaponStats)
		
		WC.ViewmodelController.recoilSpring.Damping = State.wepStats.recoil.damping
		WC.ViewmodelController.recoilSpring.Speed = State.wepStats.recoil.speed
		WC.ViewmodelController.gunRecoilSpring.Damping = State.wepStats.gunRecoil.damping
		WC.ViewmodelController.gunRecoilSpring.Speed = State.wepStats.gunRecoil.speed
		
		State.aimFOVTarget(State.wepStats.aimFovDefault or config.defaultFOV)

		if not State.wepStats.operationType or type(State.wepStats.operationType) == "string" then State.wepStats.operationType = 1 end
		if not State.wepStats.magType then State.wepStats.magType = 1 end

		local oldGun = WC.viewmodelRig.Weapon:FindFirstChildWhichIsA("Model")
		if oldGun then oldGun:Destroy() end

		local gun = assets.WeaponModels:FindFirstChild(newChild.Name):Clone()
		weldMod.WeldModel(gun, gun.Grip, false)

		if State.wepStats.Attachments then
			State.attStats = gunsmith.getAttStats(State.wepStats.Attachments)
			for slot, item in pairs(State.wepStats.Attachments) do
				if typeof(item) == "string" then
					if gun:FindFirstChild(slot) then WC.SetAttachment(gun, slot, item, gun) end
				elseif typeof(item) == "table" then
					WC.setRecursiveAttachments(gun, slot, item, gun)
				end
			end
		end

		if State.attStats.recoil then
			WC.ViewmodelController.recoilSpring.Damping *= State.attStats.recoil.damping
			WC.ViewmodelController.recoilSpring.Speed *= State.attStats.recoil.speed
		end
		if State.attStats.gunRecoil then
			WC.ViewmodelController.gunRecoilSpring.Damping *= State.attStats.gunRecoil.damping
			WC.ViewmodelController.gunRecoilSpring.Speed *= State.attStats.gunRecoil.speed
		end
		if State.attStats.aimFovDefault then
			State.aimFOVTarget(State.attStats.aimFovDefault)
		end

		for _, partName in ipairs(State.wepStats.rigParts) do
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
		State.gunModel = gun
		weldMod.BlankM6D(WC.viewmodelRig.AnimBase, gun.Grip)

		if State.firstPerson() then WC.RefreshViewmodel() end
		WC.InputController.BindGunInputs(State.firstPerson())
		WC.EquipAnim()
		WC.IdleAnim()

		State.gunAmmo = State.equipped():WaitForChild("Ammo")

		if State.wepStats.hasUBGL then
			WC.ubglAmmo = newChild:FindFirstChild("UBGLAmmo")
			local ubglAmmoPool = newChild:FindFirstChild("UBGLAmmoPool")
			if not WC.ubglAmmo then
				WC.ubglAmmo = Instance.new("IntValue", newChild)
				WC.ubglAmmo.Name = "UBGLAmmo"
				local totalStartAmmo = State.wepStats.ubgl.startAmmoPool or 6
				WC.ubglAmmo.Value = (totalStartAmmo > 0 and (not ubglAmmoPool or ubglAmmoPool.Value > 0)) and 1 or 0
			end
			if not ubglAmmoPool then
				ubglAmmoPool = Instance.new("DoubleConstrainedValue", newChild)
				ubglAmmoPool.Name = "UBGLAmmoPool"
				ubglAmmoPool.MaxValue = State.wepStats.ubgl.maxAmmoPool or 12
				local totalStartAmmo = State.wepStats.ubgl.startAmmoPool or 6
				ubglAmmoPool.Value = totalStartAmmo > 0 and (totalStartAmmo - WC.ubglAmmo.Value) or 0
			end

			if State.wepStats.ubgl.reloadAnim then
				local animSpeed = State.wepStats.reloadSpeedModifier
				if State.attStats.reloadSpeedModifier then animSpeed *= State.attStats.reloadSpeedModifier end
				WC.AnimationController.PlayAnimation(State.wepStats.ubgl.reloadAnim, {speed = animSpeed, priority = Enum.AnimationPriority.Action2, transSpeed = 0.17}, "Reload", true)
			end
		else
			WC.ubglAmmo = nil
		end

		if not State.equipped().BoltReady.Value then
			WC.MoveBolt(State.wepStats.boltDist, true)
		end

		if config.lockFirstPerson then WC.player.CameraMode = Enum.CameraMode.LockFirstPerson end
		State.fireMode(State.equipped().FireMode.Value)
		State.holdStance(0)

		if State.gunModel.Grip:FindFirstChild("Laser") then
			WC.laserBeamFP.Attachment0 = State.gunModel.Grip.Laser
		end
		if State.attStats.laserOrigin and State.gunModel[State.attStats.laserOrigin].Main:FindFirstChild("Laser") then
			WC.laserBeamFP.Attachment0 = State.gunModel[State.attStats.laserOrigin].Main.Laser		
		end

		local animSpeed = State.wepStats.reloadSpeedModifier
		if State.attStats.reloadSpeedModifier then animSpeed *= State.attStats.reloadSpeedModifier end

		if State.wepStats.magType == 1 then
			WC.AnimationController.PlayAnimation(State.wepStats.reloadAnim, {speed = animSpeed, priority = Enum.AnimationPriority.Action2, transSpeed = 0.17}, "Reload", true)
		else
			WC.AnimationController.PlayAnimation(State.wepStats.reloadAnim, {speed = animSpeed, priority = Enum.AnimationPriority.Action2, transSpeed = 0, looped = State.gunAmmo.MagAmmo.MaxValue > 1}, "Reload", true)
			if State.wepStats.magType == 3 then
				WC.AnimationController.PlayAnimation(State.wepStats.clipReloadAnim, {speed = animSpeed, priority = Enum.AnimationPriority.Action2, transSpeed = 0.17, looped = false}, "Reload", true)
			end
		end

		local newEquipAnim = WC.AnimationController.PlayAnimation(State.wepStats.equipAnim, {priority = Enum.AnimationPriority.Action2}, "Equip", true)
		newEquipAnim.Stopped:Connect(function() State.equipping(false) end)

		WC.AnimationController.PlayAnimation(State.wepStats.boltChamber, {priority = Enum.AnimationPriority.Action2, transSpeed = 0.05, looped = false}, "Chamber", true)
		if State.wepStats.operationType == 2 or State.wepStats.operationType == 3 then
			WC.AnimationController.PlayAnimation(State.wepStats.boltOpen, {priority = Enum.AnimationPriority.Action2, transSpeed = 0, looped = false}, "BoltOpen", true)
			WC.AnimationController.PlayAnimation(State.wepStats.boltClose, {priority = Enum.AnimationPriority.Action2, looped = false}, "BoltClose", true)
		end
		
		task.delay(1, function() WC.lastGunModel = newChild end)
	end
end

function WC.OnTriggerIntent(inputState, inputObject)
	local inputBegan = Enum.UserInputState.Begin
	if inputState == inputBegan then
		WC.cancelReload = true
		if not (State.sprinting() or State.reloading()) then
			WC.holdingM1 = true
			if not WC.IsLoaded() and not (State.equipped():GetAttribute("FireMode") == WC.fireModes.Manual and State.equipped():GetAttribute("MagAmmo") > 0) then
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
		WC.Unequip(State.equipped())
		WC.playerDropGun:Fire()
	end
end

function WC.OnReloadIntent(inputState, inputObject)
	local inputBegan = Enum.UserInputState.Begin
	if inputState == inputBegan and not State.reloading() and WC.cycled then
		if State.fireMode() == WC.fireModes.UBGL and State.wepStats.hasUBGL then
			local ubglAmmoPool = State.equipped():FindFirstChild("UBGLAmmoPool")
			if WC.ubglAmmo and WC.ubglAmmo.Value == 0 and ubglAmmoPool and ubglAmmoPool.Value > 0 then
				WC.ReloadAnim()
			end
		else
			if State.wepStats.infiniteAmmo or State.gunAmmo.ArcadeAmmoPool.Value > 0 then
				if (State.wepStats.openBolt and State.gunAmmo.MagAmmo.Value < State.gunAmmo.MagAmmo.MaxValue) then
					WC.ReloadAnim()
				else
					if (State.wepStats.operationType == 4 and State.equipped().Chambered.Value)
						or (State.wepStats.operationType == 3 and State.gunAmmo.MagAmmo.Value + 1 >= State.gunAmmo.MagAmmo.MaxValue)
						or (State.wepStats.operationType == 2 and State.gunAmmo.MagAmmo.Value >= State.gunAmmo.MagAmmo.MaxValue) then
						return
					end
					WC.ReloadAnim()
				end
			end
		end
	end
end

function WC.OnChamberIntent(inputState, inputObject)
	local inputBegan = Enum.UserInputState.Begin
	if inputState == inputBegan and not State.reloading() and WC.cycled then
		WC.ChamberAnim()
	end
end

function WC.OnSwitchSightsIntent(inputState, inputObject)
	local inputBegan = Enum.UserInputState.Begin
	if inputState == inputBegan and State.aiming() and (State.gunModel:FindFirstChild("AimPart2") or (State.attStats.aimParts and State.attStats.aimParts["AimPart2"])) then
		-- TODO: move this out to the CharacterClient - it should modify state and WC should do the rest.
		local tempIndex = State.sightIndex() + 1
		if State.gunModel:FindFirstChild("AimPart"..tempIndex) or (State.attStats.aimParts and State.attStats.aimParts["AimPart"..tempIndex]) then
			State.sightIndex(tempIndex)
			WC.PlayRepSound("AimUp")
		else
			State.sightIndex(1)
			WC.PlayRepSound("AimDown")
		end
	end
end

function WC.OnHoldUpIntent(inputState, inputObject)
	local inputBegan = Enum.UserInputState.Begin
	if inputState == inputBegan and not State.reloading() then
		WC.ChangeHoldStance(1)
	end
end

function WC.OnHoldPatrolIntent(inputState, inputObject)
	local inputBegan = Enum.UserInputState.Begin
	if inputState == inputBegan and not State.reloading() then
		WC.ChangeHoldStance(2)
	end
end

function WC.OnHoldDownIntent(inputState, inputObject)
	local inputBegan = Enum.UserInputState.Begin
	if inputState == inputBegan and not State.reloading() then
		WC.ChangeHoldStance(3)
	end
end

function WC.OnSwitchFireModeIntent(inputState, inputObject)
	local inputBegan = Enum.UserInputState.Begin
	if inputState == inputBegan then
		WC.AnimationController.PlayAnimation(State.wepStats.switchAnim, {transSpeed = 0.2})
	end
end

function WC.OnToggleLaserIntent(inputState, inputObject)
	local inputBegan = Enum.UserInputState.Begin
	if inputState == inputBegan then
		local lazerbeem = State.gunModel.Grip:FindFirstChild("Laser")
		if State.attStats.laserOrigin then lazerbeem = State.gunModel[State.attStats.laserOrigin].Main:FindFirstChild("Laser") end
		if lazerbeem then
			State.laserEnabled(not State.laserEnabled())
		end
	end
end

function WC.OnToggleFlashlightIntent(inputState, inputObject)
	local inputBegan = Enum.UserInputState.Begin
	if inputState == inputBegan then
		State.flashlightEnabled(not State.flashlightEnabled())
	end
end

function WC.OnAimIntent(inputState, inputObject)
	local inputBegan = Enum.UserInputState.Begin
	if not UserInputService.TouchEnabled and not config.toggleAiming then -- Hold aiming
		if inputState == inputBegan and State.firstPerson() and not State.freeLook() and not State.blocked() then
			State.aimHeld(true)
			State.sprinting(false)
			if State.stance() == 0 then WC.MovementController.UpdateWalkSpeed(config.walkSpeed) end
			WC.ToggleAiming(true)
		elseif not State.sprinting() and State.aiming() then -- Not aiming
			State.aimHeld(false)
			WC.ToggleAiming(false)
		end
	elseif inputState == inputBegan then -- Mobile and toggle aiming
		if State.firstPerson() and not State.freeLook() and not State.blocked() and not State.aiming() then
			State.aimHeld(true)
			State.sprinting(false)
			if State.stance() == 0 then WC.MovementController.UpdateWalkSpeed(config.walkSpeed) end
			WC.ToggleAiming(true)
		else
			State.aimHeld(false)
			WC.ToggleAiming(false)
		end
	end
end

function WC.UpdateHeartbeat(dt)
	local freeLook = State.freeLook()
	local blocked = State.blocked()
	local fireMode = State.fireMode()
	if
		State.equipped()
		and not State.dead()
		and not State.sprinting()
		and not State.reloading()
		and WC.holdingM1 
		and WC.cycled then
		if WC.canFire and not blocked and State.holdStance() == 0 and WC.IsLoaded() and fireMode > 0 and (config.fireWithFreelook or (not config.fireWithFreelook and not freeLook)) and not State.equipping() then
			if not State.firstPerson() and not config.thirdPersonFiring then return end

			local currentStats = WC.GetCurrentWepStats()
			if currentStats.fireAnim then WC.AnimationController.PlayAnimation(currentStats.fireAnim, {priority = Enum.AnimationPriority.Action2, looped = false}) end

			WC.bulletsCurrentlyFired += 1
			WC.ejected = false

			if fireMode == WC.fireModes.Semi or fireMode == WC.fireModes.Manual or fireMode == WC.fireModes.UBGL or (fireMode == WC.fireModes.Burst and WC.bulletsCurrentlyFired >= currentStats.burstNumber) then
				WC.canFire = false
				WC.holdingM1 = false
			end
			WC.cycled = false
			local curModel = State.gunModel
			local recoilStats = currentStats.recoil
			local vertRecoil = recoilStats.vertical
			local horzRecoil = recoilStats.horizontal
			local camShake = recoilStats.camShake
			local aimReduction = recoilStats.aimReduction or 1

			if State.attStats.recoil then
				vertRecoil *= State.attStats.recoil.vertical
				horzRecoil *= State.attStats.recoil.horizontal
				camShake *= State.attStats.recoil.camShake
				aimReduction *= State.attStats.recoil.aimReduction
			end
			if State.bipodEnabled() then
				vertRecoil /= 4
				horzRecoil /= 4
			end
			if State.aiming() then
				vertRecoil /= aimReduction
				horzRecoil /= aimReduction
			end
			if State.stance() == 2 then
				vertRecoil /= 2
				horzRecoil /= 2
			end

			WC.ViewmodelController.recoilSpring:shove(Vector3.new(vertRecoil, math.random(-horzRecoil,horzRecoil), camShake))

			local gunRecoilStats = currentStats.gunRecoil
			local gunVertRecoil = gunRecoilStats.vertical
			local gunHorzRecoil = gunRecoilStats.horizontal
			local punchMultiplier = gunRecoilStats.punchMultiplier

			if State.attStats.gunRecoil then
				gunVertRecoil *= State.attStats.gunRecoil.vertical
				gunHorzRecoil *= State.attStats.gunRecoil.horizontal
				punchMultiplier *= State.attStats.gunRecoil.punchMultiplier
			end
			if State.stance() == 2 then
				gunVertRecoil /= 1.5
				gunHorzRecoil /= 1.5
			end
			if State.bipodEnabled() then
				gunVertRecoil /= 3
				gunHorzRecoil /= 3
			end

			WC.ViewmodelController.gunRecoilSpring:shove(Vector3.new(gunVertRecoil, math.random(-gunHorzRecoil,gunHorzRecoil), punchMultiplier))

			if fireMode ~= WC.fireModes.Manual and fireMode ~= WC.fireModes.UBGL then
				WC.EjectShell()
			end

			if fireMode ~= WC.fireModes.UBGL then
				local bulletHandlerPart = State.wepStats.bulletHandler and State.gunModel:FindFirstChild(State.wepStats.bulletHolder)
				if bulletHandlerPart then
					local bulletNumber = State.gunAmmo.MagAmmo.MaxValue - (State.gunAmmo.MagAmmo.Value - 1)
					local tempBulletPart = bulletHandlerPart:FindFirstChild("Bullet"..bulletNumber)
					if tempBulletPart then tempBulletPart.Transparency = 1 end
				end
			end

			local tempGunModel = State.gunModel
			if not State.firstPerson() then tempGunModel = WC.GetThirdPersonGunModel() end

			local muzzleName = "Muzzle"
			if fireMode == WC.fireModes.UBGL then muzzleName = "UBGLMuzzle" end
			local muCh = State.attStats.muzzleChance or State.wepStats.muzzleChance
			if State.attStats.newMuzzleDevice then tempGunModel = tempGunModel[State.attStats.newMuzzleDevice] end
			bulletHandler.FireFX(WC.player, tempGunModel, muzzleName, muCh, fireMode == WC.fireModes.UBGL)

			WC.PlayRepSound("Fire")

			if fireMode ~= WC.fireModes.UBGL then
				WC.MoveBolt(currentStats.boltDist)
			end

			local shotCount = (currentStats.shotgun and currentStats.shotgunPellets) or 1
			for _ = 1, shotCount do
				local bulletOrigin, bulletDirection
				local tempSpread = currentStats.spread * 100
				local spreadCFrame = CFrame.Angles(math.rad(math.random(-tempSpread, tempSpread) / 100), math.rad(math.random(-tempSpread, tempSpread) / 100), 0)

				local muzzlePoint = WC.GetMuzzlePoint(State.firstPerson() and curModel or WC.GetThirdPersonGunModel())
				bulletOrigin = muzzlePoint.WorldCFrame.Position
				bulletDirection = (muzzlePoint.WorldCFrame * spreadCFrame).LookVector

				local muVe = currentStats.muzzleVelocity
				if State.attStats.muzzleVelocityReplace then muVe = State.attStats.muzzleVelocityReplace end
				if State.attStats.muzzleVelocity then muVe *= State.attStats.muzzleVelocity end
				local bulletVelocity = (bulletDirection * muVe * 3.5)

				local tracerColor = nil
				local TrTi = currentStats.tracerTiming
				if TrTi and State.attStats.tracerTiming then TrTi = currentStats.tracerTiming end
				if fireMode ~= WC.fireModes.UBGL and currentStats.tracers and State.gunAmmo.MagAmmo.Value % TrTi == 0 then
					tracerColor = State.attStats.tracerColor or currentStats.tracerColor
				end

				local bulletData = State.equipped()
				if fireMode == WC.fireModes.UBGL then
					bulletData = {
						Tool = State.equipped(),
						fireMode = fireMode,
						SPH_Weapon = State.equipped().SPH_Weapon
					}
				end

				bulletHandler.FireBullet(WC.thirdPersonRig, bulletOrigin, bulletDirection, bulletVelocity, bulletData, WC.player, tracerColor)
			end

			local firePoint = State.firstPerson() and WC.GetMuzzlePoint(curModel) or WC.GetMuzzlePoint(WC.GetThirdPersonGunModel())
			WC.playerFire:Fire(firePoint.WorldCFrame)

			local cycleTime = currentStats.fireRate
			if fireMode == WC.fireModes.Burst and currentStats.burstFireRate then cycleTime = currentStats.burstFireRate end
			if State.attStats.fireRate then cycleTime *= State.attStats.fireRate end

			if currentStats.projectile ~= "Bullet" then
				WC.SetProjectileTransparency(State.gunModel, 1)
			end

			task.wait(60 / cycleTime)
			if not State.equipped() then return end

			if currentStats.autoChamber and fireMode == WC.fireModes.Manual and not State.reloading() then
				WC.ChamberAnim()
			end
			WC.cycled = true
		else
			if not WC.IsLoaded() then
				if fireMode == WC.fireModes.Manual and State.gunAmmo.MagAmmo.Value > 0 and not State.reloading() and not WC.chambering then
					WC.ChamberAnim()
					WC.holdingM1 = false
				end
			elseif State.wepStats.emptyCloseBolt then
				WC.repChamber:Fire()
				WC.MoveBolt(CFrame.new())
			end
		end
	end
end

function WC.UpdateRender(dt)
	if not State.equipped() or WC.camera.CameraType ~= Enum.CameraType.Custom then return end

	local bipodPart = State.gunModel.Grip:FindFirstChild("Bipod")
	local bipodModel = State.gunModel
	if State.attStats.Bipod and State.gunModel[State.attStats.Bipod].Main:FindFirstChild("Bipod") then
		bipodPart = State.gunModel[State.attStats.Bipod].Main.Bipod
		bipodModel = State.gunModel[State.attStats.Bipod]
	end

	if bipodPart then
		local bipodRayParams = RaycastParams.new()
		bipodRayParams.FilterType = Enum.RaycastFilterType.Exclude
		bipodRayParams.FilterDescendantsInstances = WC.bipodRayIgnore
		bipodRayParams.RespectCanCollide = true
		local rayResult = workspace:Raycast(bipodPart.WorldCFrame.Position, Vector3.new(0,-1.5,0), bipodRayParams)
		WC.canBipod = rayResult ~= nil

		if WC.canBipod ~= State.bipodEnabled() then
			State.bipodEnabled(WC.canBipod)
		end
	end

	if State.laserEnabled() then
		local laserPoint
		if State.gunModel.Grip:FindFirstChild("Laser") then laserPoint = State.firstPerson() and State.gunModel.Grip.Laser or WC.GetThirdPersonGunModel().Grip.Laser end
		if State.attStats.laserOrigin then laserPoint = State.firstPerson() and State.gunModel[State.attStats.laserOrigin].Main.Laser or WC.GetThirdPersonGunModel()[State.attStats.laserOrigin].Main.Laser end
		if not WC.laserDotPoint then return end
		
		local laserRayParams = RaycastParams.new()
		laserRayParams.FilterType = Enum.RaycastFilterType.Exclude
		laserRayParams.FilterDescendantsInstances = {State.gunModel, WC.character}
		laserRayParams.RespectCanCollide = true
		if laserPoint then
			local rayResult = workspace:Raycast(laserPoint.WorldPosition, laserPoint.WorldCFrame.LookVector * 600, laserRayParams)
			if rayResult then
				WC.laserDotPoint.WorldPosition = rayResult.Position
			else
				WC.laserDotPoint.WorldPosition = laserPoint.WorldCFrame.LookVector * 600
			end
		end
	end

	for _, sight:BasePart in ipairs(WC.sights) do
		local frame = sight:FindFirstChild("SurfaceGui") and sight.SurfaceGui:FindFirstChild("Frame")
		if not frame then continue end
		local sightUI = frame:FindFirstChild("Reticle") or frame:FindFirstChild("Holo")
		if not sightUI then continue end

		local dist = sight.CFrame:PointToObjectSpace(WC.camera.CFrame.Position)/sight.Size
		sightUI.Position = UDim2.fromScale(0.5 + dist.X, 0.5 - dist.Y)	

		if sightUI.Name == "Holo" then
			local newSize = WC.camera.FieldOfView / 70
			sightUI.Size = UDim2.fromScale(newSize,newSize)
		end
	end
end

function WC.OnKeyframeReached(animName, keyframeName, newAnim, animType)
	if State.gunModel.Grip:FindFirstChild(keyframeName) then WC.PlayRepSound(keyframeName) end
	if keyframeName == "MagIn" then
		if State.equipped() and (not State.equipped().Chambered.Value or State.wepStats.openBolt) and State.wepStats.autoChamber then
			State.reloading(true)
			local animNameToPlay = State.equipped().BoltReady.Value and State.wepStats.boltChamber or State.wepStats.boltClose
			WC.AnimationController.StopAnimation(animName, 0.4)
			WC.AnimationController.PlayAnimation(animNameToPlay, {priority = Enum.AnimationPriority.Action2, transSpeed = 0.05})
		end
		local bulletHandlerPart = State.wepStats.bulletHandler and State.gunModel:FindFirstChild(State.wepStats.bulletHolder)
		if bulletHandlerPart then
			for _, child in bulletHandlerPart:GetChildren() do
				if child:IsA("BasePart") and string.sub(child.Name, 1, 6) == "Bullet" then child.Transparency = 0 end
			end
		end
		WC.repReload:Fire()
		if State.wepStats.magType > 1 then newAnim.DidLoop:Once(function() WC.AnimationController.StopAnimation(animName) end) end
	elseif keyframeName == "ShellInsert" or keyframeName == "BulletInsert" then
		if WC.cancelReload then
			WC.cancelReload = false
			newAnim.Looped = false
			newAnim.Stopped:Once(function()
				if not State.equipped() then return end
				WC.AnimationController.StopAnimation(newAnim.Name)
				if not State.equipped().BoltReady.Value or State.wepStats.openBolt then
					WC.AnimationController.PlayAnimation(State.wepStats.boltClose, {priority = Enum.AnimationPriority.Action2})
				else
					State.reloading(false)
				end
			end)
		elseif State.gunAmmo.MagAmmo.Value + 1 >= State.gunAmmo.MagAmmo.MaxValue or State.gunAmmo.ArcadeAmmoPool.Value - 1 <= 0 then
			newAnim.DidLoop:Once(function()
				if not State.equipped() then return end
				WC.AnimationController.StopAnimation(newAnim.Name)
				if not State.equipped().BoltReady.Value or State.wepStats.operationType == 3 or State.wepStats.openBolt then
					WC.AnimationController.PlayAnimation(State.wepStats.boltClose, {priority = Enum.AnimationPriority.Action2})
				else
					State.reloading(false)
				end
			end)
		end
		local bulletHandlerPart = State.wepStats.bulletHolder and State.gunModel:FindFirstChild(State.wepStats.bulletHolder)
		if bulletHandlerPart then
			local bulletNumber = State.gunAmmo.MagAmmo.MaxValue - State.gunAmmo.MagAmmo.Value
			local tempBulletPart = bulletHandlerPart:FindFirstChild("Bullet"..bulletNumber)
			if tempBulletPart then tempBulletPart.Transparency = 0 end
		end
		WC.repReload:Fire()
	elseif keyframeName == "ClipInsertEnd" then
		local ammoNeeded = State.gunAmmo.MagAmmo.MaxValue - State.gunAmmo.MagAmmo.Value
		local clipSize = State.wepStats.clipSize or State.attStats.magazineCapacity or State.wepStats.magazineCapacity
		local animSpeed = State.wepStats.reloadSpeedModifier
		if State.attStats.reloadSpeedModifier then animSpeed *= State.attStats.reloadSpeedModifier end
		if ammoNeeded > 0 then
			WC.AnimationController.StopAnimation(newAnim.Name)
			if ammoNeeded >= clipSize then
				WC.AnimationController.PlayAnimation(State.wepStats.clipReloadAnim, {looped = true, speed = animSpeed, priority = Enum.AnimationPriority.Action2, transSpeed = 0.17})
			else
				WC.AnimationController.PlayAnimation(State.wepStats.reloadAnim, {speed = animSpeed, priority = Enum.AnimationPriority.Action2, transSpeed = 0.17}, "Reload")
			end
		end
	elseif keyframeName == "ClipInsert" then
		WC.repReload:Fire()
	elseif keyframeName == "SlideRelease" or keyframeName == "BoltClose" then
		WC.repChamber:Fire()
		State.reloading(false)
		WC.MoveBolt(CFrame.new(), true)
	elseif keyframeName == "SlidePull" and State.equipped() and State.equipped().Chambered.Value then
		WC.EjectShell()
	elseif keyframeName == "Switch" and not State.reloading() then
		WC.SwitchFireMode()
	elseif keyframeName == "MagGrab" then
		WC.SetProjectileTransparency(State.gunModel, 0)
		WC.SetProjectileTransparency(WC.GetThirdPersonGunModel(), 0)
		WC.magGrab:Fire()
	elseif keyframeName == "BoltOpen" then
		WC.repBoltOpen:Fire()
		if not WC.ejected then WC.EjectShell() end
	end
end

function WC.OnAnimationStopped(animName, newAnim, animType)
	if animType == "Reload" then
		State.reloading(false)
		if State.equipped() and State.equipped().Chambered.Value then
			WC.SetProjectileTransparency(State.gunModel, 0)
		end
	end
end

return WC