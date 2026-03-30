local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local assets = ReplicatedStorage:WaitForChild("SPH_Assets")
local config = require(assets.GameConfig)
local modules = assets.Modules
local gunsmith = require(modules.Gunsmith)
local bulletHandler = require(modules.BulletHandler)
local shellEjection = require(modules.ShellEjection)
local weldMod = require(modules.WeldMod)
local bridgeNet = require(modules.BridgeNet)

local State = require(script.Parent.CharacterState)

local storageCFrame = CFrame.new(1000000, 0, 0)

local WeaponController = {
	holdingM1 = false,
	cycled = true,
	equipping = false,
	canFire = true,
	laserEnabled = false,
	flashlightEnabled = false,
	canBipod = false,
	bipodEnabled = false,
	bipodRayIgnore = {},
	ejected = true,
	cancelReload = false,
	chambering = false,
	bulletsCurrentlyFired = 0,
	ubglAmmo = nil,
	sights = {},
	sightIndex = 1,
	lastGunModel = nil,
	fireModes = { Safe = 0, Semi = 1, Auto = 2, Burst = 3, UBGL = 4, Manual = 5 },
	curFireMode = 0,
	holdStance = 0,
	holdAnim = nil,
	aimSensitivity = 1,
	aimFOVTarget = 70, -- Will be set correctly on init
	
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
	defaultFOV = 70,
	
	AnimationController = nil,
	ViewmodelController = nil,
	MovementController = nil,
	InputController = nil,
	
	RefreshViewmodel = nil,
	ToggleAiming = nil,
	ChangeDoF = nil,
	GetSprintHeld = nil,
}

WeaponController.switchWeapon = bridgeNet.CreateBridge("SwitchWeapon")
WeaponController.playerFire = bridgeNet.CreateBridge("PlayerFire")
WeaponController.playSound = bridgeNet.CreateBridge("PlaySound")
WeaponController.repReload = bridgeNet.CreateBridge("Reload")
WeaponController.repChamber = bridgeNet.CreateBridge("PlayerChamber")
WeaponController.moveBolt = bridgeNet.CreateBridge("MoveBolt")
WeaponController.switchFireMode = bridgeNet.CreateBridge("SwitchFireMode")
WeaponController.playerDropGun = bridgeNet.CreateBridge("PlayerDropGun")
WeaponController.playerToggleAttachment = bridgeNet.CreateBridge("PlayerToggleAttachment")
WeaponController.repBoltOpen = bridgeNet.CreateBridge("RepBoltOpen")
WeaponController.magGrab = bridgeNet.CreateBridge("MagGrab")

function WeaponController.Initialize(params)
	WeaponController.player = params.player
	WeaponController.character = params.character
	WeaponController.humanoid = params.humanoid
	WeaponController.humanoidRootPart = params.humanoidRootPart
	WeaponController.camera = params.camera
	WeaponController.viewmodelRig = params.viewmodelRig
	WeaponController.thirdPersonRig = params.thirdPersonRig
	WeaponController.rigType = params.rigType
	
	WeaponController.laserDotUI = params.laserDotUI
	WeaponController.laserDotPoint = params.laserDotPoint
	WeaponController.laserBeamFP = params.laserBeamFP
	WeaponController.laserBeamTP = params.laserBeamTP
	WeaponController.defaultFOV = params.defaultFOV
	WeaponController.aimFOVTarget = params.defaultFOV
	
	WeaponController.bipodRayIgnore = {params.character}
	
	WeaponController.AnimationController = params.AnimationController
	WeaponController.ViewmodelController = params.ViewmodelController
	WeaponController.MovementController = params.MovementController
	WeaponController.InputController = params.InputController
	
	WeaponController.RefreshViewmodel = params.RefreshViewmodel
	WeaponController.ToggleAiming = params.ToggleAiming
	WeaponController.ChangeDoF = params.ChangeDoF
	WeaponController.GetSprintHeld = params.GetSprintHeld
	
	WeaponController.character.ChildAdded:Connect(function(child)
		WeaponController.Equip(child)
	end)
	
	WeaponController.character.ChildRemoved:Connect(function(child)
		if State.equipped and child:FindFirstChild("SPH_Weapon") and assets.WeaponModels:FindFirstChild(child.Name) then
			WeaponController.Unequip(child)
		end
	end)
end

function WeaponController.PlayRepSound(soundName)
	if not State.dead and State.wepStats then
		local soundToPlay
		if WeaponController.curFireMode == WeaponController.fireModes.UBGL and State.wepStats.hasUBGL then
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

		if soundToPlay and State.equipped then
			if State.firstPerson then
				soundToPlay:Play()
			else
				local clonedSound = soundToPlay:Clone()
				clonedSound.Parent = WeaponController.humanoidRootPart
				clonedSound:Play()
				Debris:AddItem(clonedSound, clonedSound.TimeLength)
			end
			WeaponController.playSound:Fire(soundName, State.firstPerson)
		end
	end
end

function WeaponController.GetCurrentWepStats()
	if WeaponController.curFireMode == WeaponController.fireModes.UBGL and State.wepStats.hasUBGL then
		return State.wepStats.getStatsForMode(4)
	else
		return State.wepStats
	end
end

function WeaponController.IsLoaded()
	local currentStats = WeaponController.GetCurrentWepStats()
	if WeaponController.curFireMode == WeaponController.fireModes.UBGL and State.wepStats.hasUBGL then
		return WeaponController.ubglAmmo and WeaponController.ubglAmmo.Value > 0
	else
		return not currentStats.openBolt and State.equipped.Chambered.Value or currentStats.openBolt and State.gunAmmo.MagAmmo.Value > 0
	end
end

function WeaponController.GetMuzzlePoint(gunModel)
	if WeaponController.curFireMode == WeaponController.fireModes.UBGL and State.wepStats.hasUBGL then
		local ubglMuzzle = gunModel.Grip:FindFirstChild("UBGLMuzzle")
		if ubglMuzzle then return ubglMuzzle end
	end
	return gunModel.Grip.Muzzle
end

function WeaponController.MoveBolt(direction:CFrame, silent:boolean)
	bulletHandler.MoveBolt(State.gunModel, State.wepStats, direction, State.gunAmmo.MagAmmo.Value)
	bulletHandler.MoveBolt(WeaponController.thirdPersonRig.Weapon:FindFirstChildWhichIsA("Model"), State.wepStats, direction, State.gunAmmo.MagAmmo.Value)
	if State.gunAmmo.MagAmmo.Value <= 0 and not silent then
		WeaponController.PlayRepSound("Empty")
	end
	WeaponController.moveBolt:Fire(direction, State.gunAmmo.MagAmmo.Value)
end

function WeaponController.ToggleADS(toggle)
	if (State.wepStats and State.wepStats.ADSEnabled) or (State.attStats and State.attStats.ADSEnabled) then
		local aimingTime = (State.wepStats.aimTime and State.wepStats.aimTime / 20) or 0.2
		if State.attStats.aimTime then aimingTime *= State.attStats.aimTime end
		
		local tweenInfo = TweenInfo.new(aimingTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, aimingTime)

		if not toggle then
			for _, child in pairs(State.gunModel:GetDescendants()) do
				if child.Name == "REG" then
					TweenService:Create(child, tweenInfo, {Transparency = 0}):Play()
				elseif child.Name == "ADS" then
					TweenService:Create(child, tweenInfo, {Transparency = 1}):Play()
				end
			end
		elseif toggle then
			for _, child in pairs(State.gunModel:GetDescendants()) do
				if child.Name == "REG" then
					TweenService:Create(child, tweenInfo, {Transparency = 1}):Play()
				elseif child.Name == "ADS" then
					TweenService:Create(child, tweenInfo, {Transparency = 0}):Play()
				end
			end
		end
	end
end

function WeaponController.ToggleBipod(bipodModel, toggle)
	for _, bipObject in pairs(bipodModel:GetChildren()) do
		if bipObject.Name == "Bipod_On" then
			bipObject.Transparency = toggle and 0 or 1
		elseif bipObject.Name == "Bipod_Off" then
			bipObject.Transparency = toggle and 1 or 0
		end
	end
end

function WeaponController.EjectShell()
	WeaponController.ejected = true
	if State.wepStats.shellEject then
		if State.firstPerson then
			shellEjection.ejectShell(WeaponController.player, State.equipped, State.gunModel)
		else
			shellEjection.ejectShell(WeaponController.player, State.equipped, WeaponController.thirdPersonRig.Weapon:FindFirstChildWhichIsA("Model"))
		end
	end
end

function WeaponController.GetThirdPersonGunModel()
	return WeaponController.thirdPersonRig.Weapon:FindFirstChildWhichIsA("Model")
end

function WeaponController.SwitchFireMode()
	repeat
		WeaponController.curFireMode += 1
		if WeaponController.curFireMode > 5 then WeaponController.curFireMode = 0 break end
	until State.wepStats.fireSwitch[WeaponController.curFireMode]
	WeaponController.switchFireMode:Fire(WeaponController.curFireMode)
end

function WeaponController.ChangeHoldStance(newStance)
	if State.aiming then return end
	if WeaponController.holdStance == newStance and WeaponController.holdAnim then
		WeaponController.AnimationController.StopAnimation(WeaponController.holdAnim.Name, 0.3)
		WeaponController.holdAnim = nil
		WeaponController.holdStance = 0
	else
		WeaponController.holdStance = newStance
		if WeaponController.holdAnim then WeaponController.AnimationController.StopAnimation(WeaponController.holdAnim.Name, 0.3) end

		local animToPlay
		if WeaponController.holdStance == 1 and State.wepStats.holdUpAnim then
			animToPlay = State.wepStats.holdUpAnim
		elseif WeaponController.holdStance == 2 and State.wepStats.patrolAnim then
			animToPlay = State.wepStats.patrolAnim
		elseif WeaponController.holdStance == 3 and State.wepStats.holdDownAnim then
			animToPlay = State.wepStats.holdDownAnim
		end

		if animToPlay then
			WeaponController.holdAnim = WeaponController.AnimationController.PlayAnimation(animToPlay, {looped = true, priority = Enum.AnimationPriority.Action, transSpeed = 0.3})
			WeaponController.holdAnim:Play()
		elseif WeaponController.holdAnim then
			WeaponController.holdAnim = nil
		end
	end
end

function WeaponController.ChamberAnim()
	local animNameToPlay
	if State.equipped.BoltReady.Value or WeaponController.curFireMode == WeaponController.fireModes.Manual then
		animNameToPlay = State.wepStats.boltChamber
	else
		animNameToPlay = State.wepStats.boltClose
	end

	if animNameToPlay then
		State.reloading = true
		WeaponController.chambering = true
		WeaponController.ChangeHoldStance(0)
		local playingAnim:AnimationTrack = WeaponController.AnimationController.PlayAnimation(animNameToPlay, {priority = Enum.AnimationPriority.Action2, transSpeed = 0.05})
		playingAnim.Stopped:Once(function()
			WeaponController.chambering = false
		end)
	end
end

function WeaponController.IdleAnim()
	WeaponController.AnimationController.PlayAnimation(State.wepStats.idleAnim, {looped = true, priority = Enum.AnimationPriority.Idle})
end

function WeaponController.EquipAnim()
	WeaponController.AnimationController.PlayAnimation(State.wepStats.equipAnim, {priority = Enum.AnimationPriority.Action2}, "Equip")
	task.wait(0.1)
	
	if not State.wepStats then return end
	local projectile = State.gunModel:FindFirstChild(State.wepStats.projectile)
	if (State.wepStats.openBolt or not State.equipped.Chambered.Value) and projectile and State.wepStats.projectile ~= "Bullet" then
		projectile.LocalTransparencyModifier = 1
		for _, child in ipairs(projectile:GetDescendants()) do
			if child:IsA("BasePart") then child.LocalTransparencyModifier = 1 end
		end
	end
end

function WeaponController.ReloadAnim()
	if not State.equipped then return end
	WeaponController.cancelReload = false
	WeaponController.ChangeHoldStance(0)
	State.reloading = true

	local animSpeed = State.wepStats.reloadSpeedModifier
	if State.attStats.reloadSpeedModifier then animSpeed *= State.attStats.reloadSpeedModifier end

	if WeaponController.curFireMode == WeaponController.fireModes.UBGL and State.wepStats.hasUBGL then
		local ubglStats = State.wepStats.getStatsForMode(4)
		if ubglStats.reloadAnim then
			WeaponController.AnimationController.PlayAnimation(ubglStats.reloadAnim, {speed = animSpeed, priority = Enum.AnimationPriority.Action2, transSpeed = 0.17}, "Reload")
		else
			WeaponController.AnimationController.PlayAnimation(State.wepStats.reloadAnim, {speed = animSpeed, priority = Enum.AnimationPriority.Action2, transSpeed = 0.17}, "Reload")
		end
		return
	end

	if State.wepStats.operationType == 3 or (State.wepStats.operationType == 2 and State.gunAmmo.MagAmmo.Value <= 0 and not State.equipped.Chambered.Value) then
		local boltOpenTrack = WeaponController.AnimationController.PlayAnimation(State.wepStats.boltOpen, {speed = animSpeed, priority = Enum.AnimationPriority.Action2, transSpeed = 0.17})
		if not boltOpenTrack then
			warn("To use operation type "..State.wepStats.operationType..", a 'boltOpen' animation is required.")
			State.reloading = false
			return
		end
		boltOpenTrack.Stopped:Once(function()
			if State.wepStats.magType == 3
				and (State.gunAmmo.MagAmmo.MaxValue - State.gunAmmo.MagAmmo.Value) >= (State.wepStats.clipSize or State.attStats.magazineCapacity or State.wepStats.magazineCapacity)
				and State.gunAmmo.ArcadeAmmoPool.Value >= (State.wepStats.clipSize or State.attStats.magazineCapacity or State.wepStats.magazineCapacity) then
				
				WeaponController.AnimationController.PlayAnimation(State.wepStats.clipReloadAnim, {looped = true, speed = animSpeed, priority = Enum.AnimationPriority.Action2, transSpeed = 0.17})
			else
				if WeaponController.lastGunModel and WeaponController.lastGunModel.Name ~= State.gunModel.Name then return end
				local bulletInsert = WeaponController.AnimationController.PlayAnimation(State.wepStats.reloadAnim, {speed = animSpeed, priority = Enum.AnimationPriority.Action2, transSpeed = 0.17, looped = true}, "Reload")
				if State.wepStats.magType > 1 then bulletInsert.Looped = true end
			end
		end)
	else
		WeaponController.AnimationController.PlayAnimation(State.wepStats.reloadAnim, {speed = animSpeed, priority = Enum.AnimationPriority.Action2, transSpeed = 0.17}, "Reload")
	end
end

function WeaponController.Unequip(tool)
	WeaponController.viewmodelRig.AnimBase.CFrame = storageCFrame
	WeaponController.lastGunModel = State.gunModel
	
	WeaponController.switchWeapon:Fire()
	if tool == State.equipped then
		State.equipped = nil
		State.wepStats = nil
		State.attStats = {}
	end
	UserInputService.MouseIconEnabled = true
	WeaponController.ToggleAiming(false)
	WeaponController.AnimationController.StopAll()

	if config.lockFirstPerson then
		WeaponController.player.CameraMode = Enum.CameraMode.Classic
	end

	WeaponController.sights = {}
	if WeaponController.ChangeDoF then WeaponController.ChangeDoF(0, 0, 0, 0) end

	WeaponController.holdStance = 0
	WeaponController.holdAnim = nil
	WeaponController.laserEnabled = false
	WeaponController.flashlightEnabled = false
	WeaponController.bipodEnabled = false
	WeaponController.laserDotUI.Enabled = false
	WeaponController.laserBeamFP.Enabled = false
	WeaponController.laserBeamTP.Enabled = false

	WeaponController.InputController.UnbindGunInputs()
end

function WeaponController.SetAttachment(weapon, attachmentSlot, weaponAttachment, parentPart)
	local newAttachment = gunsmith.placeAttachment(weapon, attachmentSlot, weaponAttachment, parentPart)
	if not assets.Attachments:FindFirstChild(weaponAttachment) then warn(weaponAttachment.." Not found!") return end
	
	local newAttStats = require(assets.Attachments[weaponAttachment].AttStats)
	if newAttStats.ADSEnabled then
		if not State.attStats.ADSEnabled then State.attStats.ADSEnabled = newAttStats.ADSEnabled end
	end

	for _, part in ipairs(newAttachment:GetChildren()) do
		if part.Name == "SightReticle" then
			table.insert(WeaponController.sights, part)
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

function WeaponController.setRecursiveAttachments(weapon, attachmentSlot, weaponAttachment, parentPart)
	if not weaponAttachment or weaponAttachment == "" then return end
	if typeof(weaponAttachment) == "string" then
		if not parentPart:FindFirstChild(attachmentSlot) then return end
		WeaponController.SetAttachment(weapon, attachmentSlot, weaponAttachment, parentPart)
	elseif typeof(weaponAttachment) == "table" then
		local subAttachment = weaponAttachment[1]
		local subAttachmentNodes = weaponAttachment[2]
		WeaponController.SetAttachment(weapon, attachmentSlot, subAttachment, parentPart)
		for item, name in pairs(subAttachmentNodes) do
			WeaponController.setRecursiveAttachments(weapon, item, name, weapon[subAttachment])
		end
	end
end

function WeaponController.Equip(newChild)
	if newChild:FindFirstChild("SPH_Weapon") and not assets.WeaponModels:FindFirstChild(newChild.Name) then return end

	if newChild:FindFirstChild("SPH_Weapon") and not State.dead and (not WeaponController.humanoid.Sit or WeaponController.humanoid.Sit and not WeaponController.MovementController.vehicleSeated) then
		State.reloading = false
		UserInputService.MouseIconEnabled = false
		WeaponController.ViewmodelController.ResetHipRotation()
		WeaponController.equipping = true
		WeaponController.laserEnabled = false
		WeaponController.cycled = true
		WeaponController.chambering = false

		WeaponController.switchWeapon:Fire(newChild)

		State.equipped = newChild
		State.wepStats = require(State.equipped.SPH_Weapon.WeaponStats)
		WeaponController.ViewmodelController.recoilSpring.Damping = State.wepStats.recoil.damping
		WeaponController.ViewmodelController.recoilSpring.Speed = State.wepStats.recoil.speed
		WeaponController.ViewmodelController.gunRecoilSpring.Damping = State.wepStats.gunRecoil.damping
		WeaponController.ViewmodelController.gunRecoilSpring.Speed = State.wepStats.gunRecoil.speed
		
		WeaponController.aimFOVTarget = State.wepStats.aimFovDefault or WeaponController.defaultFOV
		WeaponController.aimSensitivity = State.wepStats.aimSpeed

		if not State.wepStats.operationType or type(State.wepStats.operationType) == "string" then State.wepStats.operationType = 1 end
		if not State.wepStats.magType then State.wepStats.magType = 1 end

		local oldGun = WeaponController.viewmodelRig.Weapon:FindFirstChildWhichIsA("Model")
		if oldGun then oldGun:Destroy() end

		local gun = assets.WeaponModels:FindFirstChild(newChild.Name):Clone()
		weldMod.WeldModel(gun, gun.Grip, false)

		if State.wepStats.Attachments then
			State.attStats = gunsmith.getAttStats(State.wepStats.Attachments)
			for slot, item in pairs(State.wepStats.Attachments) do
				if typeof(item) == "string" then
					if gun:FindFirstChild(slot) then WeaponController.SetAttachment(gun, slot, item, gun) end
				elseif typeof(item) == "table" then
					WeaponController.setRecursiveAttachments(gun, slot, item, gun)
				end
			end
		end

		if State.attStats.recoil then
			WeaponController.ViewmodelController.recoilSpring.Damping *= State.attStats.recoil.damping
			WeaponController.ViewmodelController.recoilSpring.Speed *= State.attStats.recoil.speed
		end
		if State.attStats.gunRecoil then
			WeaponController.ViewmodelController.gunRecoilSpring.Damping *= State.attStats.gunRecoil.damping
			WeaponController.ViewmodelController.gunRecoilSpring.Speed *= State.attStats.gunRecoil.speed
		end
		if State.attStats.aimFovDefault then
			WeaponController.aimFOVTarget = State.attStats.aimFovDefault
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
			if part.Name == "SightReticle" then table.insert(WeaponController.sights, part) end
		end

		gun.Parent = WeaponController.viewmodelRig.Weapon
		State.gunModel = gun
		weldMod.BlankM6D(WeaponController.viewmodelRig.AnimBase, gun.Grip)

		if State.firstPerson then WeaponController.RefreshViewmodel() end
		WeaponController.InputController.BindGunInputs(State.firstPerson)
		WeaponController.MovementController.ToggleSprint(WeaponController.GetSprintHeld())
		WeaponController.EquipAnim()
		WeaponController.IdleAnim()

		State.gunAmmo = newChild:WaitForChild("Ammo")

		if State.wepStats.hasUBGL then
			WeaponController.ubglAmmo = newChild:FindFirstChild("UBGLAmmo")
			local ubglAmmoPool = newChild:FindFirstChild("UBGLAmmoPool")
			if not WeaponController.ubglAmmo then
				WeaponController.ubglAmmo = Instance.new("IntValue", newChild)
				WeaponController.ubglAmmo.Name = "UBGLAmmo"
				local totalStartAmmo = State.wepStats.ubgl.startAmmoPool or 6
				WeaponController.ubglAmmo.Value = (totalStartAmmo > 0 and (not ubglAmmoPool or ubglAmmoPool.Value > 0)) and 1 or 0
			end
			if not ubglAmmoPool then
				ubglAmmoPool = Instance.new("DoubleConstrainedValue", newChild)
				ubglAmmoPool.Name = "UBGLAmmoPool"
				ubglAmmoPool.MaxValue = State.wepStats.ubgl.maxAmmoPool or 12
				local totalStartAmmo = State.wepStats.ubgl.startAmmoPool or 6
				ubglAmmoPool.Value = totalStartAmmo > 0 and (totalStartAmmo - WeaponController.ubglAmmo.Value) or 0
			end

			if State.wepStats.ubgl.reloadAnim then
				local animSpeed = State.wepStats.reloadSpeedModifier
				if State.attStats.reloadSpeedModifier then animSpeed *= State.attStats.reloadSpeedModifier end
				WeaponController.AnimationController.PlayAnimation(State.wepStats.ubgl.reloadAnim, {speed = animSpeed, priority = Enum.AnimationPriority.Action2, transSpeed = 0.17}, "Reload", true)
			end
		else
			WeaponController.ubglAmmo = nil
		end

		if not State.equipped.BoltReady.Value then
			WeaponController.MoveBolt(State.wepStats.boltDist, true)
		end

		if config.lockFirstPerson then WeaponController.player.CameraMode = Enum.CameraMode.LockFirstPerson end
		WeaponController.curFireMode = State.equipped.FireMode.Value

		if State.gunModel.Grip:FindFirstChild("Laser") then
			WeaponController.laserBeamFP.Attachment0 = State.gunModel.Grip.Laser
		end
		if State.attStats.laserOrigin and State.gunModel[State.attStats.laserOrigin].Main:FindFirstChild("Laser") then
			WeaponController.laserBeamFP.Attachment0 = State.gunModel[State.attStats.laserOrigin].Main.Laser		
		end

		local animSpeed = State.wepStats.reloadSpeedModifier
		if State.attStats.reloadSpeedModifier then animSpeed *= State.attStats.reloadSpeedModifier end

		if State.wepStats.magType == 1 then
			WeaponController.AnimationController.PlayAnimation(State.wepStats.reloadAnim, {speed = animSpeed, priority = Enum.AnimationPriority.Action2, transSpeed = 0.17}, "Reload", true)
		else
			WeaponController.AnimationController.PlayAnimation(State.wepStats.reloadAnim, {speed = animSpeed, priority = Enum.AnimationPriority.Action2, transSpeed = 0, looped = State.gunAmmo.MagAmmo.MaxValue > 1}, "Reload", true)
			if State.wepStats.magType == 3 then
				WeaponController.AnimationController.PlayAnimation(State.wepStats.clipReloadAnim, {speed = animSpeed, priority = Enum.AnimationPriority.Action2, transSpeed = 0.17, looped = false}, "Reload", true)
			end
		end

		local newEquipAnim = WeaponController.AnimationController.PlayAnimation(State.wepStats.equipAnim, {priority = Enum.AnimationPriority.Action2}, "Equip", true)
		newEquipAnim.Stopped:Connect(function() WeaponController.equipping = false end)

		WeaponController.AnimationController.PlayAnimation(State.wepStats.boltChamber, {priority = Enum.AnimationPriority.Action2, transSpeed = 0.05, looped = false}, "Chamber", true)
		if State.wepStats.operationType == 2 or State.wepStats.operationType == 3 then
			WeaponController.AnimationController.PlayAnimation(State.wepStats.boltOpen, {priority = Enum.AnimationPriority.Action2, transSpeed = 0, looped = false}, "BoltOpen", true)
			WeaponController.AnimationController.PlayAnimation(State.wepStats.boltClose, {priority = Enum.AnimationPriority.Action2, looped = false}, "BoltClose", true)
		end
		
		task.delay(1, function() WeaponController.lastGunModel = newChild end)
	end
end

function WeaponController.HandleInput(actionName, inputState)
	local inputBegan = Enum.UserInputState.Begin
	if actionName == "SPH_Trigger" then
		if inputState == inputBegan then
			WeaponController.cancelReload = true
			if not (State.sprinting or State.reloading) then
				WeaponController.holdingM1 = true
				if not WeaponController.IsLoaded() and not (State.equipped:GetAttribute("FireMode") == WeaponController.fireModes.Manual and State.equipped:GetAttribute("MagAmmo") > 0) then
					WeaponController.PlayRepSound("Click")
				end
			end
		else
			WeaponController.holdingM1 = false
			WeaponController.canFire = true
			WeaponController.bulletsCurrentlyFired = 0
		end
	elseif actionName == "SPH_DropGun" and inputState == inputBegan then
		WeaponController.Unequip(State.equipped)
		WeaponController.playerDropGun:Fire()
	elseif actionName == "SPH_Reload" and inputState == inputBegan and not State.reloading and WeaponController.cycled then
		if WeaponController.curFireMode == WeaponController.fireModes.UBGL and State.wepStats.hasUBGL then
			local ubglAmmoPool = State.equipped:FindFirstChild("UBGLAmmoPool")
			if WeaponController.ubglAmmo and WeaponController.ubglAmmo.Value == 0 and ubglAmmoPool and ubglAmmoPool.Value > 0 then
				WeaponController.ReloadAnim()
			end
		else
			if State.wepStats.infiniteAmmo or State.gunAmmo.ArcadeAmmoPool.Value > 0 then
				if (State.wepStats.openBolt and State.gunAmmo.MagAmmo.Value < State.gunAmmo.MagAmmo.MaxValue) then
					WeaponController.ReloadAnim()
				else
					if (State.wepStats.operationType == 4 and State.equipped.Chambered.Value)
						or (State.wepStats.operationType == 3 and State.gunAmmo.MagAmmo.Value + 1 >= State.gunAmmo.MagAmmo.MaxValue)
						or (State.wepStats.operationType == 2 and State.gunAmmo.MagAmmo.Value >= State.gunAmmo.MagAmmo.MaxValue) then
						return
					end
					WeaponController.ReloadAnim()
				end
			end
		end
	elseif actionName == "SPH_Chamber" and inputState == inputBegan and not State.reloading and WeaponController.cycled then
		WeaponController.ChamberAnim()
	elseif actionName == "SPH_SwitchSights" and inputState == inputBegan and State.aiming and (State.gunModel:FindFirstChild("AimPart2") or (State.attStats.aimParts and State.attStats.aimParts["AimPart2"])) then
		local tempIndex = WeaponController.sightIndex + 1
		if State.gunModel:FindFirstChild("AimPart"..tempIndex) then
			WeaponController.sightIndex = tempIndex
			WeaponController.PlayRepSound("AimUp")	
		elseif State.attStats.aimParts then
			if State.attStats.aimParts["AimPart"..tempIndex] then
				WeaponController.sightIndex = tempIndex
				WeaponController.PlayRepSound("AimUp")
			else
				WeaponController.sightIndex = 1
				WeaponController.PlayRepSound("AimDown")
			end
		else
			WeaponController.sightIndex = 1
			WeaponController.PlayRepSound("AimDown")
		end
		if (State.attStats.ADSEnabled and State.attStats.ADSEnabled[WeaponController.sightIndex]) or (State.wepStats.ADSEnabled and State.wepStats.ADSEnabled[WeaponController.sightIndex]) then
			WeaponController.ToggleADS(true)
		else
			WeaponController.ToggleADS(false)
		end
	elseif actionName == "SPH_HoldUp" and inputState == inputBegan and not State.reloading then
		WeaponController.ChangeHoldStance(1)
	elseif actionName == "SPH_HoldPatrol" and inputState == inputBegan and not State.reloading then
		WeaponController.ChangeHoldStance(2)
	elseif actionName == "SPH_HoldDown" and inputState == inputBegan and not State.reloading then
		WeaponController.ChangeHoldStance(3)
	elseif actionName == "SPH_SwitchFireMode" and inputState == inputBegan then
		WeaponController.AnimationController.PlayAnimation(State.wepStats.switchAnim, {transSpeed = 0.2})
	elseif actionName == "SPH_ToggleLaser" and inputState == inputBegan then
		local lazerbeem = State.gunModel.Grip:FindFirstChild("Laser")
		if State.attStats.laserOrigin then lazerbeem = State.gunModel[State.attStats.laserOrigin].Main:FindFirstChild("Laser") end
		if lazerbeem then
			WeaponController.laserEnabled = not WeaponController.laserEnabled
			if not State.firstPerson then WeaponController.laserBeamTP.Enabled = true end
			WeaponController.PlayRepSound("Button")
			WeaponController.playerToggleAttachment:Fire(1, WeaponController.laserEnabled)
			WeaponController.laserDotUI.Dot.ImageColor3 = lazerbeem.Color.Value
		end
	elseif actionName == "SPH_ToggleFlashlight" and inputState == inputBegan then
		local flashlight = State.gunModel.Grip:FindFirstChild("Flashlight")
		if flashlight then
			local light = flashlight:FindFirstChildWhichIsA("Light")
			WeaponController.flashlightEnabled = not WeaponController.flashlightEnabled
			light.Enabled = WeaponController.flashlightEnabled
			WeaponController.PlayRepSound("Button")
			WeaponController.playerToggleAttachment:Fire(0, light.Enabled)
			if not WeaponController.flashlightEnabled then
				WeaponController.thirdPersonRig.Weapon:FindFirstChildWhichIsA("Model").Grip.Flashlight:FindFirstChildWhichIsA("Light").Enabled = false
			elseif not State.firstPerson then
				WeaponController.thirdPersonRig.Weapon:FindFirstChildWhichIsA("Model").Grip.Flashlight:FindFirstChildWhichIsA("Light").Enabled = true
			end
		end
		if State.attStats.flashlights_client then
			if not flashlight then WeaponController.flashlightEnabled = not WeaponController.flashlightEnabled end
			for _, lightAttachment in ipairs(State.attStats.flashlights_client) do
				local flashlite = lightAttachment.Main:FindFirstChild("Flashlight")
				if flashlite then
					local light = flashlite:FindFirstChildWhichIsA("Light")
					light.Enabled = WeaponController.flashlightEnabled
					WeaponController.PlayRepSound("Button")
					WeaponController.playerToggleAttachment:Fire(0, light.Enabled)
					if not WeaponController.flashlightEnabled then
						WeaponController.thirdPersonRig.Weapon:FindFirstChildWhichIsA("Model")[lightAttachment.Name].Main.Flashlight:FindFirstChildWhichIsA("Light").Enabled = false
					elseif not State.firstPerson then
						WeaponController.thirdPersonRig.Weapon:FindFirstChildWhichIsA("Model")[lightAttachment.Name].Main.Flashlight:FindFirstChildWhichIsA("Light").Enabled = true
					end
				end
			end
		end
	end
end

function WeaponController.UpdateHeartbeat(dt, freeLook, blocked)
	if State.equipped and not State.dead and WeaponController.holdingM1 and WeaponController.cycled and not State.sprinting and not State.reloading then
		if WeaponController.canFire and not blocked and WeaponController.holdStance == 0 and WeaponController.IsLoaded() and WeaponController.curFireMode > 0 and (config.fireWithFreelook or (not config.fireWithFreelook and not freeLook)) and not WeaponController.equipping then
			if not State.firstPerson and not config.thirdPersonFiring then return end

			local currentStats = WeaponController.GetCurrentWepStats()
			if currentStats.fireAnim then WeaponController.AnimationController.PlayAnimation(currentStats.fireAnim, {priority = Enum.AnimationPriority.Action2, looped = false}) end

			WeaponController.bulletsCurrentlyFired += 1
			WeaponController.ejected = false

			if WeaponController.curFireMode == WeaponController.fireModes.Semi or WeaponController.curFireMode == WeaponController.fireModes.Manual or WeaponController.curFireMode == WeaponController.fireModes.UBGL or (WeaponController.curFireMode == WeaponController.fireModes.Burst and WeaponController.bulletsCurrentlyFired >= currentStats.burstNumber) then
				WeaponController.canFire = false
				WeaponController.holdingM1 = false
			end
			WeaponController.cycled = false
			local curModel = State.gunModel
			local recoilStats = currentStats.recoil
			local vertRecoil = recoilStats.vertical
			local horzRecoil = recoilStats.horizontal

			if State.attStats.recoil then
				vertRecoil *= State.attStats.recoil.vertical
				horzRecoil *= State.attStats.recoil.horizontal
				recoilStats.camShake *= State.attStats.recoil.camShake
				recoilStats.aimReduction *= State.attStats.recoil.aimReduction
			end
			if WeaponController.bipodEnabled then
				vertRecoil /= 4
				horzRecoil /= 4
			end
			if State.aiming then
				vertRecoil /= recoilStats.aimReduction
				horzRecoil /= recoilStats.aimReduction
			end
			if State.stance == 2 then
				vertRecoil /= 2
				horzRecoil /= 2
			end

			WeaponController.ViewmodelController.recoilSpring:shove(Vector3.new(vertRecoil, math.random(-horzRecoil,horzRecoil), recoilStats.camShake))

			recoilStats = currentStats.gunRecoil
			vertRecoil = recoilStats.vertical
			horzRecoil = recoilStats.horizontal

			if State.attStats.gunRecoil then
				vertRecoil *= State.attStats.gunRecoil.vertical
				horzRecoil *= State.attStats.gunRecoil.horizontal
				recoilStats.punchMultiplier *= State.attStats.gunRecoil.punchMultiplier
			end
			if State.stance == 2 then
				vertRecoil /= 1.5
				horzRecoil /= 1.5
			end
			if WeaponController.bipodEnabled then
				vertRecoil /= 3
				horzRecoil /= 3
			end

			WeaponController.ViewmodelController.gunRecoilSpring:shove(Vector3.new(vertRecoil, math.random(-horzRecoil,horzRecoil), recoilStats.punchMultiplier))

			if WeaponController.curFireMode ~= WeaponController.fireModes.Manual and WeaponController.curFireMode ~= WeaponController.fireModes.UBGL then
				WeaponController.EjectShell()
			end

			if WeaponController.curFireMode ~= WeaponController.fireModes.UBGL then
				local bulletHandlerPart = State.wepStats.bulletHandler and State.gunModel:FindFirstChild(State.wepStats.bulletHolder)
				if bulletHandlerPart then
					local bulletNumber = State.gunAmmo.MagAmmo.MaxValue - (State.gunAmmo.MagAmmo.Value - 1)
					local tempBulletPart = bulletHandlerPart:FindFirstChild("Bullet"..bulletNumber)
					if tempBulletPart then tempBulletPart.Transparency = 1 end
				end
			end

			local tempGunModel = State.gunModel
			if not State.firstPerson then tempGunModel = WeaponController.GetThirdPersonGunModel() end

			local muzzleName = "Muzzle"
			if WeaponController.curFireMode == WeaponController.fireModes.UBGL then muzzleName = "UBGLMuzzle" end
			local muCh = State.attStats.muzzleChance or State.wepStats.muzzleChance
			if State.attStats.newMuzzleDevice then tempGunModel = tempGunModel[State.attStats.newMuzzleDevice] end
			bulletHandler.FireFX(WeaponController.player, tempGunModel, muzzleName, muCh, WeaponController.curFireMode == WeaponController.fireModes.UBGL)

			WeaponController.PlayRepSound("Fire")

			if WeaponController.curFireMode ~= WeaponController.fireModes.UBGL then
				WeaponController.MoveBolt(currentStats.boltDist)
			end

			local shotCount = (currentStats.shotgun and currentStats.shotgunPellets) or 1
			repeat
				shotCount -= 1
				local bulletOrigin, bulletDirection
				local tempSpread = currentStats.spread * 100
				local spreadCFrame = CFrame.Angles(math.rad(math.random(-tempSpread, tempSpread) / 100), math.rad(math.random(-tempSpread, tempSpread) / 100), 0)

				local muzzlePoint
				if State.firstPerson then
					muzzlePoint = WeaponController.GetMuzzlePoint(curModel)
					bulletOrigin = muzzlePoint.WorldCFrame.Position
					bulletDirection = (muzzlePoint.WorldCFrame * spreadCFrame).LookVector
				else
					local tempModel = WeaponController.GetThirdPersonGunModel()
					muzzlePoint = WeaponController.GetMuzzlePoint(tempModel)
					bulletOrigin = muzzlePoint.WorldCFrame.Position
					bulletDirection = (muzzlePoint.WorldCFrame * spreadCFrame).LookVector
				end

				local muVe = currentStats.muzzleVelocity
				if State.attStats.muzzleVelocityReplace then muVe = State.attStats.muzzleVelocityReplace end
				if State.attStats.muzzleVelocity then muVe *= State.attStats.muzzleVelocity end
				local bulletVelocity = (bulletDirection * muVe * 3.5)

				local tracerColor = nil
				local TrTi = currentStats.tracerTiming
				if TrTi and State.attStats.tracerTiming then TrTi = currentStats.tracerTiming end
				if WeaponController.curFireMode ~= WeaponController.fireModes.UBGL and currentStats.tracers and State.gunAmmo.MagAmmo.Value % TrTi == 0 then
					tracerColor = State.attStats.tracerColor or currentStats.tracerColor
				end

				local bulletData = State.equipped
				if WeaponController.curFireMode == WeaponController.fireModes.UBGL then
					bulletData = {
						Tool = State.equipped,
						fireMode = WeaponController.curFireMode,
						SPH_Weapon = State.equipped.SPH_Weapon
					}
				end

				bulletHandler.FireBullet(WeaponController.thirdPersonRig, bulletOrigin, bulletDirection, bulletVelocity, bulletData, WeaponController.player, tracerColor)
			until shotCount <= 0

			local firePoint = State.firstPerson and WeaponController.GetMuzzlePoint(curModel) or WeaponController.GetMuzzlePoint(WeaponController.GetThirdPersonGunModel())
			WeaponController.playerFire:Fire(firePoint.WorldCFrame)

			local cycleTime = currentStats.fireRate
			if WeaponController.curFireMode == WeaponController.fireModes.Burst and currentStats.burstFireRate then cycleTime = currentStats.burstFireRate end
			if State.attStats.fireRate then cycleTime *= State.attStats.fireRate end

			if State.gunModel and currentStats.projectile ~= "Bullet" and State.gunModel:FindFirstChild(currentStats.projectile) then
				local projectile = State.gunModel:FindFirstChild(currentStats.projectile)
				projectile.LocalTransparencyModifier = 1
				for _, child in ipairs(projectile:GetDescendants()) do
					if child:IsA("BasePart") then child.LocalTransparencyModifier = 1 end
				end
			end

			task.wait(60 / cycleTime)
			if not State.equipped then return end

			if currentStats.autoChamber and WeaponController.curFireMode == WeaponController.fireModes.Manual and not State.reloading then
				WeaponController.ChamberAnim()
			end
			WeaponController.cycled = true
		else
			if not WeaponController.IsLoaded() then
				if WeaponController.curFireMode == WeaponController.fireModes.Manual and State.gunAmmo.MagAmmo.Value > 0 and not State.reloading and not WeaponController.chambering then
					WeaponController.ChamberAnim()
					WeaponController.holdingM1 = false
				end
			elseif State.wepStats.emptyCloseBolt then
				WeaponController.repChamber:Fire()
				WeaponController.MoveBolt(CFrame.new())
			end
		end
	end
end

function WeaponController.UpdateRender(dt)
	if not State.equipped or WeaponController.camera.CameraType ~= Enum.CameraType.Custom then return end

	if State.gunModel.Grip:FindFirstChild("Bipod") then
		local BipodRay = Ray.new(State.gunModel.Grip.Bipod.WorldCFrame.Position, Vector3.new(0,-1.5,0))
		local BipodHit, BipodPos, BipodNorm = workspace:FindPartOnRayWithIgnoreList(BipodRay, WeaponController.bipodRayIgnore, false, true)
		WeaponController.canBipod = BipodHit and true or false

		if WeaponController.canBipod and not WeaponController.bipodEnabled then
			WeaponController.bipodEnabled = true
			WeaponController.ToggleBipod(State.gunModel, WeaponController.bipodEnabled)
			WeaponController.PlayRepSound("Switch")
			WeaponController.playerToggleAttachment:Fire(2, WeaponController.bipodEnabled)
		end
		if WeaponController.bipodEnabled and not WeaponController.canBipod then
			WeaponController.bipodEnabled = false
			WeaponController.ToggleBipod(State.gunModel, WeaponController.bipodEnabled)
			WeaponController.PlayRepSound("Switch")
			WeaponController.playerToggleAttachment:Fire(2, WeaponController.bipodEnabled)
		end				
	end
	if State.attStats.Bipod and State.gunModel[State.attStats.Bipod].Main:FindFirstChild("Bipod") then
		local BipodRay = Ray.new(State.gunModel[State.attStats.Bipod].Main.Bipod.WorldCFrame.Position, Vector3.new(0,-1.5,0))
		local BipodHit, BipodPos, BipodNorm = workspace:FindPartOnRayWithIgnoreList(BipodRay, WeaponController.bipodRayIgnore, false, true)
		WeaponController.canBipod = BipodHit and true or false

		if WeaponController.canBipod and not WeaponController.bipodEnabled then
			WeaponController.bipodEnabled = true
			WeaponController.ToggleBipod(State.gunModel[State.attStats.Bipod], WeaponController.bipodEnabled)
			WeaponController.PlayRepSound("Switch")
			WeaponController.playerToggleAttachment:Fire(2, WeaponController.bipodEnabled)
		end
		if WeaponController.bipodEnabled and not WeaponController.canBipod then
			WeaponController.bipodEnabled = false
			WeaponController.ToggleBipod(State.gunModel[State.attStats.Bipod], WeaponController.bipodEnabled)
			WeaponController.PlayRepSound("Switch")
			WeaponController.playerToggleAttachment:Fire(2, WeaponController.bipodEnabled)
		end
	end

	if WeaponController.laserEnabled then
		if not WeaponController.laserDotUI.Enabled then
			WeaponController.laserDotUI.Enabled = true
			local lazer
			if State.attStats.laserOrigin then lazer = State.gunModel[State.attStats.laserOrigin].Main.Laser end
			if State.gunModel.Grip:FindFirstChild("Laser") then lazer = State.gunModel.Grip.Laser end
			WeaponController.laserDotUI.Dot.ImageColor3 = lazer.Color.Value

			if config.laserTrail then
				WeaponController.laserBeamFP.Color = ColorSequence.new(lazer.Color.Value)
				WeaponController.laserBeamTP.Color = ColorSequence.new(lazer.Color.Value)
				if State.firstPerson then
					WeaponController.laserBeamFP.Enabled = true
				else
					WeaponController.laserBeamTP.Enabled = true
					if not WeaponController.laserBeamTP.Attachment0 then
						if State.attStats.laserOrigin then WeaponController.laserBeamTP.Attachment0 = WeaponController.GetThirdPersonGunModel()[State.attStats.laserOrigin].Main.Laser end
						if State.gunModel.Grip:FindFirstChild("Laser") then WeaponController.laserBeamTP.Attachment0 = WeaponController.GetThirdPersonGunModel().Grip.Laser end
					end
				end
			end
		end
		local laserPoint
		if State.gunModel.Grip:FindFirstChild("Laser") then laserPoint = State.firstPerson and State.gunModel.Grip.Laser or WeaponController.GetThirdPersonGunModel().Grip.Laser end
		if State.attStats.laserOrigin then laserPoint = State.firstPerson and State.gunModel[State.attStats.laserOrigin].Main.Laser or WeaponController.GetThirdPersonGunModel()[State.attStats.laserOrigin].Main.Laser end
		if not WeaponController.laserDotPoint then return end
		
		local laserRayParams = RaycastParams.new()
		laserRayParams.FilterType = Enum.RaycastFilterType.Exclude
		laserRayParams.FilterDescendantsInstances = {State.gunModel, WeaponController.character}
		laserRayParams.RespectCanCollide = true
		local rayResult = workspace:Raycast(laserPoint.WorldPosition, laserPoint.WorldCFrame.LookVector * 600, laserRayParams)
		if rayResult then
			WeaponController.laserDotPoint.WorldPosition = rayResult.Position
		else
			WeaponController.laserDotPoint.WorldPosition = laserPoint.WorldCFrame.LookVector * 600
		end
	elseif WeaponController.laserDotUI.Enabled then
		WeaponController.laserDotUI.Enabled = false
		WeaponController.laserBeamFP.Enabled = false
		WeaponController.laserBeamTP.Enabled = false
	end
end

function WeaponController.OnKeyframeReached(animName, keyframeName, newAnim, animType)
	if State.gunModel.Grip:FindFirstChild(keyframeName) then WeaponController.PlayRepSound(keyframeName) end
	if keyframeName == "MagIn" then
		if State.equipped and (not State.equipped.Chambered.Value or State.wepStats.openBolt) and State.wepStats.autoChamber then
			State.reloading = true
			local animNameToPlay = State.equipped.BoltReady.Value and State.wepStats.boltChamber or State.wepStats.boltClose
			WeaponController.AnimationController.StopAnimation(animName, 0.4)
			WeaponController.AnimationController.PlayAnimation(animNameToPlay, {priority = Enum.AnimationPriority.Action2, transSpeed = 0.05})
		end
		local bulletHandlerPart = State.wepStats.bulletHandler and State.gunModel:FindFirstChild(State.wepStats.bulletHolder)
		if bulletHandlerPart then
			for _, child in bulletHandlerPart:GetChildren() do
				if child:IsA("BasePart") and string.sub(child.Name, 1, 6) == "Bullet" then child.Transparency = 0 end
			end
		end
		WeaponController.repReload:Fire()
		if State.wepStats.magType > 1 then newAnim.DidLoop:Once(function() WeaponController.AnimationController.StopAnimation(animName) end) end
	elseif keyframeName == "ShellInsert" or keyframeName == "BulletInsert" then
		if WeaponController.cancelReload then
			WeaponController.cancelReload = false
			newAnim.Looped = false
			newAnim.Stopped:Once(function()
				if not State.equipped then return end
				WeaponController.AnimationController.StopAnimation(newAnim.Name)
				if not State.equipped.BoltReady.Value or State.wepStats.openBolt then
					WeaponController.AnimationController.PlayAnimation(State.wepStats.boltClose, {priority = Enum.AnimationPriority.Action2})
				else
					State.reloading = false
				end
			end)
		elseif State.gunAmmo.MagAmmo.Value + 1 >= State.gunAmmo.MagAmmo.MaxValue or State.gunAmmo.ArcadeAmmoPool.Value - 1 <= 0 then
			newAnim.DidLoop:Once(function()
				if not State.equipped then return end
				WeaponController.AnimationController.StopAnimation(newAnim.Name)
				if not State.equipped.BoltReady.Value or State.wepStats.operationType == 3 or State.wepStats.openBolt then
					WeaponController.AnimationController.PlayAnimation(State.wepStats.boltClose, {priority = Enum.AnimationPriority.Action2})
				else
					State.reloading = false
				end
			end)
		end
		local bulletHandlerPart = State.wepStats.bulletHolder and State.gunModel:FindFirstChild(State.wepStats.bulletHolder)
		if bulletHandlerPart then
			local bulletNumber = State.gunAmmo.MagAmmo.MaxValue - State.gunAmmo.MagAmmo.Value
			local tempBulletPart = bulletHandlerPart:FindFirstChild("Bullet"..bulletNumber)
			if tempBulletPart then tempBulletPart.Transparency = 0 end
		end
		WeaponController.repReload:Fire()
	elseif keyframeName == "ClipInsertEnd" then
		local ammoNeeded = State.gunAmmo.MagAmmo.MaxValue - State.gunAmmo.MagAmmo.Value
		local clipSize = State.wepStats.clipSize or State.attStats.magazineCapacity or State.wepStats.magazineCapacity
		local animSpeed = State.wepStats.reloadSpeedModifier
		if State.attStats.reloadSpeedModifier then animSpeed *= State.attStats.reloadSpeedModifier end
		if ammoNeeded > 0 then
			WeaponController.AnimationController.StopAnimation(newAnim.Name)
			if ammoNeeded >= clipSize then
				WeaponController.AnimationController.PlayAnimation(State.wepStats.clipReloadAnim, {looped = true, speed = animSpeed, priority = Enum.AnimationPriority.Action2, transSpeed = 0.17})
			else
				WeaponController.AnimationController.PlayAnimation(State.wepStats.reloadAnim, {speed = animSpeed, priority = Enum.AnimationPriority.Action2, transSpeed = 0.17}, "Reload")
			end
		end
	elseif keyframeName == "ClipInsert" then
		WeaponController.repReload:Fire()
	elseif keyframeName == "SlideRelease" or keyframeName == "BoltClose" then
		WeaponController.repChamber:Fire()
		State.reloading = false
		WeaponController.MoveBolt(CFrame.new(), true)
	elseif keyframeName == "SlidePull" and State.equipped and State.equipped.Chambered.Value then
		WeaponController.EjectShell()
	elseif keyframeName == "Switch" and not State.reloading then
		WeaponController.SwitchFireMode()
	elseif keyframeName == "MagGrab" then
		if State.gunModel and State.wepStats.projectile ~= "Bullet" and State.gunModel:FindFirstChild(State.wepStats.projectile) then
			local projectile = State.gunModel:FindFirstChild(State.wepStats.projectile)
			projectile.LocalTransparencyModifier = 0
			for _, child in ipairs(projectile:GetDescendants()) do
				if child:IsA("BasePart") then child.LocalTransparencyModifier = 0 end
			end
			local tpProjectile = WeaponController.GetThirdPersonGunModel():FindFirstChild(State.wepStats.projectile)
			tpProjectile.LocalTransparencyModifier = 0
			for _, child in ipairs(tpProjectile:GetDescendants()) do
				if child:IsA("BasePart") then child.LocalTransparencyModifier = 0 end
			end
			WeaponController.magGrab:Fire()
		end
	elseif keyframeName == "BoltOpen" then
		WeaponController.repBoltOpen:Fire()
		if not WeaponController.ejected then WeaponController.EjectShell() end
	end
end

function WeaponController.OnAnimationStopped(animName, newAnim, animType)
	if animType == "Reload" then
		State.reloading = false
		if State.wepStats and State.gunModel and State.equipped and State.gunModel:FindFirstChild(State.wepStats.projectile) and State.equipped.Chambered.Value then
			local projectile = State.gunModel:FindFirstChild(State.wepStats.projectile)
			projectile.LocalTransparencyModifier = 0
			for _, child in ipairs(projectile:GetDescendants()) do
				if child:IsA("BasePart") then child.LocalTransparencyModifier = 0 end
			end
		end
	end
end

return WeaponController