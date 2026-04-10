local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Charm = require(Packages.Charm)
local Enums = require(script.Parent.Parent.Enums)
local assets = ReplicatedStorage:WaitForChild("SPH_Assets")
local config = require(assets.GameConfig)
local modules = assets.Modules
local gunsmith = require(modules.Gunsmith)
local bulletHandler = require(modules.BulletHandler)
local shellEjection = require(modules.ShellEjection)
local weldMod = require(modules.WeldMod)
local bridgeNet = require(modules.BridgeNet)
local weaponClientPersist = require(modules.WeaponClientPersist)


local RecoilModule = require(modules.Recoil.Default)

local State = require(script.Parent.CharacterState)
local WeaponState = require(script.Parent.WeaponState)
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

	InputController = nil,
	
	RefreshViewmodel = nil,
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
	
	WC.bipodRayIgnore = {params.character}
	
	WC.InputController = params.InputController
	
	WC.RefreshViewmodel = params.RefreshViewmodel
	
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

	Charm.subscribe(WeaponState.sightIndex, WC.SyncSightIndex)
	Charm.subscribe(WeaponState.flashlightEnabled, WC.SyncFlashlightEnabled)
	Charm.subscribe(WeaponState.bipodEnabled, WC.SyncBipodEnabled)
	Charm.subscribe(WeaponState.fireMode, WC.SyncFireMode)
	Charm.subscribe(WeaponState.chambering, WC.SyncChambering)

	-- Listen for animation events via signals
	AnimationEvents.KeyframeReached:Connect(WC.OnKeyframeReached)
	AnimationEvents.AnimationStopped:Connect(WC.OnAnimationStopped)
end

function WC._getLaserAttachmentPoint(model)
	if not model then
		return nil
	end
	if WeaponState.attStats.laserOrigin then
		local laserOrigin = model:FindFirstChild(WeaponState.attStats.laserOrigin)
		if laserOrigin and laserOrigin:FindFirstChild("Main") then
			return laserOrigin.Main:FindFirstChild("Laser")
		end
	end
	local grip = model:FindFirstChild("Grip")
	if grip then
		return grip:FindFirstChild("Laser")
	end
	return nil
end

function WC._weaponHasFlashlightClient(gun)
	if not gun or not gun.Grip then
		return false
	end
	if gun.Grip:FindFirstChild("Flashlight") then
		return true
	end
	if WeaponState.attStats.flashlights_client and #WeaponState.attStats.flashlights_client > 0 then
		return true
	end
	return false
end

function WC._weaponHasBipodClient(gun)
	if not gun or not WeaponState.attStats.Bipod then
		return false
	end
	local host = gun[WeaponState.attStats.Bipod]
	if not (host and host.Main and host.Main:FindFirstChild("Bipod")) then
		return false
	end
	return true
end

function WC._fireModeSupported(mode)
	if type(mode) ~= "number" or mode % 1 ~= 0 or mode < 0 or mode > 5 then
		return false
	end
	local fs = WeaponState.wepStats and WeaponState.wepStats.fireSwitch
	return fs and fs[mode] ~= nil and fs[mode] ~= false
end

function WC._sightIndexSupported(idx, gun)
	if type(idx) ~= "number" or idx % 1 ~= 0 or idx < 1 or idx > 8 then
		return false
	end
	local name = "AimPart" .. idx
	if gun:FindFirstChild(name) then
		return true
	end
	if idx == 1 and gun:FindFirstChild("AimPart") then
		return true
	end
	if WeaponState.attStats.aimParts and WeaponState.attStats.aimParts[name] then
		return true
	end
	return false
end


-- TODO: refactor this to be less ugly
function WC._applyPersistedWeaponPrefs(weaponName)
	local prefs = weaponClientPersist.get(weaponName)
	if not prefs or not State.equippedTool() then
		return
	end
	local gun = WeaponState.gunModel()
	if not gun then
		return
	end

	local baselineFireMode = WeaponState.fireMode()
	local validated = {}

	for key, val in pairs(prefs) do
		if key == "laserEnabled" and WC._getLaserAttachmentPoint(gun) then
			validated.laserEnabled = val
		elseif key == "flashlightEnabled" and WC._weaponHasFlashlightClient(gun) then
			validated.flashlightEnabled = val
		elseif key == "bipodEnabled" and WC._weaponHasBipodClient(gun) then
			validated.bipodEnabled = val
		elseif key == "fireMode" and WC._fireModeSupported(val) then
			validated.fireMode = val
		elseif key == "aimSens" then
			validated.aimSens = math.clamp(val, 0.01, 1)
		elseif key == "sightIndex" and WC._sightIndexSupported(val, gun) then
			validated.sightIndex = val
		end
	end

	local pruned = {}
	for k, v in pairs(prefs) do
		if validated[k] ~= nil then
			pruned[k] = validated[k]
		end
	end
	weaponClientPersist.set(weaponName, pruned)

	if next(validated) == nil then
		return
	end

		weaponClientPersist.beginApply()

	if validated.aimSens then
		WeaponState.aimSens(validated.aimSens)
		if WeaponState.wepStats then
			WeaponState.wepStats.aimSpeed = validated.aimSens
		end
	end
	if validated.sightIndex then
		WeaponState.sightIndex(validated.sightIndex)
	end
	if validated.fireMode ~= nil then
		WeaponState.fireMode(validated.fireMode)
		State.equippedTool().FireMode.Value = validated.fireMode
			if validated.fireMode ~= baselineFireMode then
				WC.switchFireMode:Fire(validated.fireMode)
			end
	end
	if validated.flashlightEnabled ~= nil then
		WeaponState.flashlightEnabled(validated.flashlightEnabled)
			WC.playerToggleAttachment:Fire(0, validated.flashlightEnabled)
	end
	if validated.laserEnabled ~= nil then
		WeaponState.laserEnabled(validated.laserEnabled)
			WC.playerToggleAttachment:Fire(1, validated.laserEnabled)
	end
	if validated.bipodEnabled ~= nil then
		WeaponState.bipodEnabled(validated.bipodEnabled)
			WC.playerToggleAttachment:Fire(2, validated.bipodEnabled)
	end

	WC.UpdateAttachmentsVisibility()
	weaponClientPersist.endApply()
end

function WC.UpdateAttachmentsVisibility()
	if not State.equippedTool() then return end
	
	local isFirstPerson = State.firstPerson()
	local flashlightOn = WeaponState.flashlightEnabled()
	local tpModel = WC.GetThirdPersonGunModel()
	
	local function updateLight(model, enabled)
		if not model then return end
		if model.Grip:FindFirstChild("Flashlight") then
			local light = model.Grip.Flashlight:FindFirstChildWhichIsA("Light")
			if light then light.Enabled = enabled end
		end
		if WeaponState.attStats.flashlights_client then
			for _, lightAttachment in ipairs(WeaponState.attStats.flashlights_client) do
				if model:FindFirstChild(lightAttachment.Name) then
					local light = model[lightAttachment.Name].Main.Flashlight:FindFirstChildWhichIsA("Light")
					if light then light.Enabled = enabled end
				end
			end
		end
	end
	
	updateLight(WeaponState.gunModel(), flashlightOn and isFirstPerson)
	updateLight(tpModel, flashlightOn and not isFirstPerson)
end

function WC.SyncFlashlightEnabled(enabled)
	if not State.equippedTool() then return end
	if weaponClientPersist.isApplying then
		WC.UpdateAttachmentsVisibility()
		return
	end
	WC.PlayRepSound("Button")
	WC.playerToggleAttachment:Fire(0, enabled)
	WC.UpdateAttachmentsVisibility()
end

function WC.SyncBipodEnabled(enabled)
	if not State.equippedTool() then return end
	local bipodModel = WeaponState.gunModel()
	if WeaponState.attStats.Bipod and WeaponState.gunModel()[WeaponState.attStats.Bipod].Main:FindFirstChild("Bipod") then
		bipodModel = WeaponState.gunModel()[WeaponState.attStats.Bipod]
	end
	if bipodModel then
		WC.ToggleBipod(bipodModel, enabled)
		if weaponClientPersist.isApplying then
			return
		end
		WC.PlayRepSound("Switch")
		WC.playerToggleAttachment:Fire(2, enabled)
	end
end

function WC.SyncFireMode(mode)
	if not State.equippedTool() then return end
	if weaponClientPersist.isApplying then
		return
	end
	WC.switchFireMode:Fire(mode)
end


function WC._adsMeshEnabled(sightIndex)
	return (WeaponState.attStats and WeaponState.attStats.ADSEnabled and WeaponState.attStats.ADSEnabled[sightIndex])
	or (WeaponState.wepStats and WeaponState.wepStats.ADSEnabled and WeaponState.wepStats.ADSEnabled[sightIndex])
end


function WC.SyncAiming(aiming)
	if aiming then
		-- effects n stuff
		local ADSMeshEnabled = WC._adsMeshEnabled(WeaponState.sightIndex())
		WC.PlayRepSound("AimUp")
		WC.ToggleADSMesh(ADSMeshEnabled)
		if not config.lockFirstPerson then
			Player.CameraMode = Enum.CameraMode.LockFirstPerson
		end

		-- ready the character
		State.sprinting(false)
		WeaponState.holdStance(Enums.HoldStance.Ready)


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
		WeaponState.holdStance(Enums.HoldStance.Ready)
		WC.holdingM1 = false
	end
end

function WC.SyncSightIndex(index)
	if WC._adsMeshEnabled(index) then
		WC.ToggleADSMesh(true)
	else
		WC.ToggleADSMesh(false)
	end
end



function WC.PlayRepSound(soundName)
	if not State.dead() and WeaponState.wepStats then
		local soundToPlay
		if WeaponState.fireMode() == Enums.FireModes.UBGL and WeaponState.wepStats.hasUBGL then
			soundToPlay = WeaponState.gunModel().Grip:FindFirstChild("UBGL_" .. soundName)
			if not soundToPlay then
				soundToPlay = WeaponState.gunModel().Grip:FindFirstChild(soundName)
				if WeaponState.attStats.newFireSound and soundName == "Fire" then
					soundToPlay = WeaponState.gunModel()[WeaponState.attStats.newMuzzleDevice].Main.Fire
				end
			end
		else
			soundToPlay = WeaponState.gunModel().Grip:FindFirstChild(soundName)
			if WeaponState.attStats.newFireSound and soundName == "Fire" then
				soundToPlay = WeaponState.gunModel()[WeaponState.attStats.newMuzzleDevice].Main.Fire
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
	if WeaponState.fireMode() == Enums.FireModes.UBGL and WeaponState.wepStats.hasUBGL then
		return WeaponState.wepStats.getStatsForMode(4)
	else
		return WeaponState.wepStats
	end
end

function WC.IsLoaded()
	local currentStats = WC.GetCurrentWepStats()
	if WeaponState.fireMode() == Enums.FireModes.UBGL and WeaponState.wepStats.hasUBGL then
		return WC.ubglAmmo and WC.ubglAmmo.Value > 0
	else
		return not currentStats.openBolt and State.equippedTool().Chambered.Value or currentStats.openBolt and WeaponState.gunAmmo.MagAmmo.Value > 0
	end
end

function WC.GetMuzzlePoint(gunModel)
	if WeaponState.fireMode() == Enums.FireModes.UBGL and WeaponState.wepStats.hasUBGL then
		local ubglMuzzle = gunModel.Grip:FindFirstChild("UBGLMuzzle")
		if ubglMuzzle then return ubglMuzzle end
	end
	return gunModel.Grip.Muzzle
end

function WC.MoveBolt(direction:CFrame, silent:boolean)
	bulletHandler.MoveBolt(WeaponState.gunModel(), WeaponState.wepStats, direction, WeaponState.gunAmmo.MagAmmo.Value)
	bulletHandler.MoveBolt(WC.thirdPersonRig.Weapon:FindFirstChildWhichIsA("Model"), WeaponState.wepStats, direction, WeaponState.gunAmmo.MagAmmo.Value)
	if WeaponState.gunAmmo.MagAmmo.Value <= 0 and not silent then
		WC.PlayRepSound("Empty")
	end
	WC.moveBolt:Fire(direction, WeaponState.gunAmmo.MagAmmo.Value)
end

function WC.ToggleADSMesh(toggle)
	if not ((WeaponState.wepStats and WeaponState.wepStats.ADSEnabled) or (WeaponState.attStats and WeaponState.attStats.ADSEnabled)) then
		return
	end

	local aimingTime = (WeaponState.wepStats.aimTime and WeaponState.wepStats.aimTime / 20) or 0.2
	if WeaponState.attStats.aimTime then aimingTime *= WeaponState.attStats.aimTime end

	for _, child in ipairs(WeaponState.gunModel():GetDescendants()) do
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
	if not WeaponState.wepStats or WeaponState.wepStats.projectile == "Bullet" or not model then return end
	local projectile = model:FindFirstChild(WeaponState.wepStats.projectile)
	if projectile then
		projectile.LocalTransparencyModifier = transparency
		for _, child in ipairs(projectile:GetDescendants()) do
			if child:IsA("BasePart") then child.LocalTransparencyModifier = transparency end
		end
	end
end

function WC.EjectShell()
	WC.ejected = true
	if WeaponState.wepStats.shellEject then
		if State.firstPerson() then
			shellEjection.ejectShell(WC.player, State.equippedTool(), WeaponState.gunModel())
		else
			shellEjection.ejectShell(WC.player, State.equippedTool(), WC.thirdPersonRig.Weapon:FindFirstChildWhichIsA("Model"))
		end
	end
end

function WC.GetThirdPersonGunModel()
	return WC.thirdPersonRig.Weapon:FindFirstChildWhichIsA("Model")
end

function WC.SwitchFireMode()
	local mode = WeaponState.fireMode()
	repeat
		mode += 1
		if mode > 5 then mode = 0 break end
	until WeaponState.wepStats.fireSwitch[mode]
	WeaponState.fireMode(mode)
end


function WC.Unequip(tool)
	WeaponState.equipping(false)
	WC.viewmodelRig.AnimBase.CFrame = storageCFrame
	WC.lastGunModel = WeaponState.gunModel()
	
	WC.switchWeapon:Fire()
	if tool == State.equippedTool() then
		weaponClientPersist.set(tool.Name, {
			laserEnabled = WeaponState.laserEnabled(),
			flashlightEnabled = WeaponState.flashlightEnabled(),
			bipodEnabled = WeaponState.bipodEnabled(),
			fireMode = WeaponState.fireMode(),
			aimSens = WeaponState.aimSens(),
			sightIndex = WeaponState.sightIndex(),
		})
		State.equippedTool(nil)
		WeaponState.reset()
	end
	UserInputService.MouseIconEnabled = true
	AnimationEvents.StopAllRequested:Fire()

	if config.lockFirstPerson then
		WC.player.CameraMode = Enum.CameraMode.Classic
	end

	WC.sights = {}

	WC.InputController.UnbindGunInputs()
end

function WC.SetAttachment(weapon, attachmentSlot, weaponAttachment, parentPart)
	local newAttachment = gunsmith.placeAttachment(weapon, attachmentSlot, weaponAttachment, parentPart)
	if not assets.Attachments:FindFirstChild(weaponAttachment) then warn(weaponAttachment.." Not found!") return end
	
	local newAttStats = require(assets.Attachments[weaponAttachment].AttStats)
	if newAttStats.ADSEnabled then
		if not WeaponState.attStats.ADSEnabled then WeaponState.attStats.ADSEnabled = newAttStats.ADSEnabled end
	end

	for _, part in ipairs(newAttachment:GetChildren()) do
		if part.Name == "SightReticle" then
			table.insert(WC.sights, part)
		end
		if string.find(part.Name, "AimPart") then
			if not WeaponState.attStats.aimParts then WeaponState.attStats.aimParts = {} end
			if not WeaponState.attStats.aimParts[part.Name] then
				WeaponState.attStats.aimParts[part.Name] = newAttachment.Name
			else
				local newSightIndex = 1
				for _, _ in pairs(WeaponState.attStats.aimParts) do newSightIndex += 1 end
				part.Name = "AimPart"..newSightIndex
				WeaponState.attStats.aimParts[part.Name] = newAttachment.Name
			end
			if weapon:FindFirstChild(part.Name) then
				weapon.Grip["Grip_"..part.Name]:Destroy()
				weapon[part.Name].CFrame = part.CFrame
				weldMod.Weld(weapon[part.Name], weapon.Grip)
			end
		end
	end

	if newAttachment.Main:FindFirstChild("Flashlight") then
		if not WeaponState.attStats.flashlights_client then WeaponState.attStats.flashlights_client = {} end
		table.insert(WeaponState.attStats.flashlights_client, newAttachment)
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
	if
		not newChild:FindFirstChild("SPH_Weapon")
		or (newChild:FindFirstChild("SPH_Weapon") and not assets.WeaponModels:FindFirstChild(newChild.Name))
		or State.dead()
		or (WC.humanoid.Sit and not State.vehicleSeated())
	then
		return
	end

	UserInputService.MouseIconEnabled = false

	WeaponState.reset()
	WeaponState.equipping(true)

	State.equippedTool(newChild)
	WeaponState.wepStats = require(State.equippedTool().SPH_Weapon.WeaponStats)

	WC.cycled = true
	WC.switchWeapon:Fire(newChild)


	if WeaponState.wepStats.PunchSpeed then
		WeaponState.RecoilPos.s = WeaponState.wepStats.PunchSpeed
		WeaponState.RecoilDir.s = WeaponState.wepStats.PunchSpeed
		WeaponState.RecoilUp.s = WeaponState.wepStats.PunchSpeed
	end
	if WeaponState.wepStats.PunchDamper then
		WeaponState.RecoilPos.d = WeaponState.wepStats.PunchDamper
		WeaponState.RecoilDir.d = WeaponState.wepStats.PunchDamper
		WeaponState.RecoilUp.d = WeaponState.wepStats.PunchDamper
	end


	State.aimFOVTarget(WeaponState.wepStats.aimFovDefault or config.defaultFOV)

	-- fallbacks
	if not WeaponState.wepStats.operationType or type(WeaponState.wepStats.operationType) == "string" then
		WeaponState.wepStats.operationType = 1
	end
	if not WeaponState.wepStats.magType then
		WeaponState.wepStats.magType = 1
	end

	local oldGun = WC.viewmodelRig.Weapon:FindFirstChildWhichIsA("Model")
	if oldGun then
		oldGun:Destroy()
	end

	
	local gun = assets.WeaponModels:FindFirstChild(newChild.Name):Clone()
	weldMod.WeldModel(gun, gun.Grip, false)

	--[[
	if WeaponState.wepStats.Attachments then
		WeaponState.attStats = gunsmith.getAttStats(WeaponState.wepStats.Attachments)
		for slot, item in pairs(WeaponState.wepStats.Attachments) do
			if typeof(item) == "string" then
				if gun:FindFirstChild(slot) then WC.SetAttachment(gun, slot, item, gun) end
			elseif typeof(item) == "table" then
				WC.setRecursiveAttachments(gun, slot, item, gun)
			end
		end
	end
	if WeaponState.attStats.aimFovDefault then
		State.aimFOVTarget(WeaponState.attStats.aimFovDefault)
	end
	]]

	for _, partName in ipairs(WeaponState.wepStats.rigParts) do
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
	WeaponState.gunModel(gun)

	weldMod.BlankM6D(WC.viewmodelRig.AnimBase, gun.Grip)

	if State.firstPerson() then WC.RefreshViewmodel() end
	WC.InputController.BindGunInputs(State.firstPerson())

	AnimationEvents.WeaponEquipRequested:Fire()
	AnimationEvents.WeaponIdleRequested:Fire()

	if not WeaponState.wepStats then return end
	if WeaponState.wepStats.openBolt or not State.equippedTool().Chambered.Value then
		WC.SetProjectileTransparency(WeaponState.gunModel(), 1)
	end

	WeaponState.gunAmmo = State.equippedTool():WaitForChild("Ammo")

	if WeaponState.wepStats.hasUBGL then
		WC.ubglAmmo = newChild:FindFirstChild("UBGLAmmo")
		local ubglAmmoPool = newChild:FindFirstChild("UBGLAmmoPool")
		if not WC.ubglAmmo then
			WC.ubglAmmo = Instance.new("IntValue", newChild)
			WC.ubglAmmo.Name = "UBGLAmmo"
			local totalStartAmmo = WeaponState.wepStats.ubgl.startAmmoPool or 6
			WC.ubglAmmo.Value = (totalStartAmmo > 0 and (not ubglAmmoPool or ubglAmmoPool.Value > 0)) and 1 or 0
		end
		if not ubglAmmoPool then
			ubglAmmoPool = Instance.new("DoubleConstrainedValue", newChild)
			ubglAmmoPool.Name = "UBGLAmmoPool"
			ubglAmmoPool.MaxValue = WeaponState.wepStats.ubgl.maxAmmoPool or 12
			local totalStartAmmo = WeaponState.wepStats.ubgl.startAmmoPool or 6
			ubglAmmoPool.Value = totalStartAmmo > 0 and (totalStartAmmo - WC.ubglAmmo.Value) or 0
		end

		if WeaponState.wepStats.ubgl.reloadAnim then
			local animSpeed = WeaponState.wepStats.reloadSpeedModifier
			if WeaponState.attStats.reloadSpeedModifier then animSpeed *= WeaponState.attStats.reloadSpeedModifier end
			AnimationEvents.PlayAnimationRequested:Fire(WeaponState.wepStats.ubgl.reloadAnim, {speed = animSpeed, priority = Enum.AnimationPriority.Action2, transSpeed = 0.17}, "Reload")
		end
	else
		WC.ubglAmmo = nil
	end

	if not State.equippedTool().BoltReady.Value then
		WC.MoveBolt(WeaponState.wepStats.boltDist, true)
	end

	if config.lockFirstPerson then WC.player.CameraMode = Enum.CameraMode.LockFirstPerson end
	WeaponState.fireMode(State.equippedTool().FireMode.Value)
	WeaponState.holdStance(Enums.HoldStance.Ready)

	WC._applyPersistedWeaponPrefs(newChild.Name)

	task.delay(1, function() WC.lastGunModel = newChild end)
end

function WC.OnTriggerIntent(inputState, inputObject)
	local inputBegan = Enum.UserInputState.Begin
	if inputState == inputBegan then
		WC.cancelReload = true
		if not (State.sprinting() or WeaponState.reloading()) then
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
	if inputState == inputBegan and WeaponState.canManipulate() and WC.cycled then
		WeaponState.holdStance(Enums.HoldStance.Ready)

		if WeaponState.fireMode() == Enums.FireModes.UBGL and WeaponState.wepStats.hasUBGL then
			local ubglAmmoPool = State.equippedTool():FindFirstChild("UBGLAmmoPool")
			if WC.ubglAmmo and WC.ubglAmmo.Value == 0 and ubglAmmoPool and ubglAmmoPool.Value > 0 then
				WC.cancelReload = false
				AnimationEvents.ReloadRequested:Fire(WC.lastGunModel and WC.lastGunModel.Name)
			end
		else
			if WeaponState.wepStats.infiniteAmmo or WeaponState.gunAmmo.ArcadeAmmoPool.Value > 0 then
				if (WeaponState.wepStats.openBolt and WeaponState.gunAmmo.MagAmmo.Value < WeaponState.gunAmmo.MagAmmo.MaxValue) then
					WC.cancelReload = false
					AnimationEvents.ReloadRequested:Fire(WC.lastGunModel and WC.lastGunModel.Name)
				else
					if (WeaponState.wepStats.operationType == 4 and State.equippedTool().Chambered.Value)
						or (WeaponState.wepStats.operationType == 3 and WeaponState.gunAmmo.MagAmmo.Value + 1 >= WeaponState.gunAmmo.MagAmmo.MaxValue)
						or (WeaponState.wepStats.operationType == 2 and WeaponState.gunAmmo.MagAmmo.Value >= WeaponState.gunAmmo.MagAmmo.MaxValue) then
						return
					end
					WC.cancelReload = false
					AnimationEvents.ReloadRequested:Fire(WC.lastGunModel and WC.lastGunModel.Name)
				end
			end
		end
	end
end

function WC.OnChamberIntent(inputState, inputObject)
	local inputBegan = Enum.UserInputState.Begin
	if inputState == inputBegan and WeaponState.canManipulate() and WC.cycled then
		WeaponState.chambering(true)
	end
end

function WC.SyncChambering(chambering)
	WeaponState.holdStance(Enums.HoldStance.Ready)
end

function WC.OnSwitchSightsIntent(inputState, inputObject)
	local inputBegan = Enum.UserInputState.Begin
	if inputState == inputBegan and State.aiming() and (WeaponState.gunModel():FindFirstChild("AimPart2") or (WeaponState.attStats.aimParts and WeaponState.attStats.aimParts["AimPart2"])) then
		local tempIndex = WeaponState.sightIndex() + 1
		if WeaponState.gunModel():FindFirstChild("AimPart"..tempIndex) or (WeaponState.attStats.aimParts and WeaponState.attStats.aimParts["AimPart"..tempIndex]) then
			WeaponState.sightIndex(tempIndex)
			WC.PlayRepSound("AimUp")
		else
			WeaponState.sightIndex(1)
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
		WeaponState.flashlightEnabled(not WeaponState.flashlightEnabled())
	end
end

function WC.OnAimIntent(inputState, inputObject)
	local inputBegan = inputState == Enum.UserInputState.Begin
	if not UserInputService.TouchEnabled and not config.toggleAiming then -- Hold aiming
		if inputBegan and State.firstPerson() and not State.freeLook() and not WeaponState.blocked() then
			WeaponState.aimHeld(true)
			State.aiming(true)
		else
			WeaponState.aimHeld(false)
			State.aiming(false)
		end
	elseif inputBegan then -- Mobile and toggle aiming
		if State.firstPerson() and not State.freeLook() and not WeaponState.blocked() and not State.aiming() then
			WeaponState.aimHeld(true)
			State.aiming(true)
		else
			WeaponState.aimHeld(false)
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

local SP = require(modules.Spring.Default)

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

		if WeaponState.bipodEnabled() then
			vr  = vr/3
			hr = hr/3

			vP = vP*0.75

			hP = hP/2.5
			dP = dP/2.5

			WeaponState.RecoilCF = RecoilModule.BipodRecoil(
				WeaponState.RecoilCF, finalRecoilPunch, WeaponState.RecoilFactor,vP,hP,dP)
		else
			WeaponState.RecoilCF = RecoilModule.Recoil(
				WeaponState.RecoilCF, finalRecoilPunch, WeaponState.RecoilFactor,vP,hP,dP)
		end

		WeaponState.RecoilPos.t = WeaponState.RecoilCF.Position
		WeaponState.RecoilDir.t = WeaponState.RecoilCF.LookVector
		WeaponState.RecoilUp.t = WeaponState.RecoilCF.UpVector
		
		WeaponState.CameraSpring.t = WeaponState.CameraSpring.t + Vector3.new(vr, hr, 0)
		WeaponState.CameraSpring.p = WeaponState.CameraSpring.p + Vector3.new(vr, hr, 0) * 0.5
		local duration = 0.25 --ServerConfig.AimRecoverDuration
		task.wait(duration/5 * WeaponState.CameraSpring.s / SP.cs)
		--cwait(duration/5 * CameraSpring.s / SP.cs)
		local t = 0
		if wepStats.AimRecoverDuration then
			duration = wepStats.AimRecoverDuration
		end
		while t <= duration do
			local step = RunService.Heartbeat:Wait()
			t = t + step
			WeaponState.CameraSpring.t = WeaponState.CameraSpring.t - Vector3.new(vr, hr, 0) 
				* wepStats.AimRecover * step / duration
		end
	end)()
	
end



function WC.UpdateHeartbeat(dt)
	if not State.equippedTool() or State.dead() then return end
	
	-- General state checks: prevents execution if sprinting, reloading, chambering, or not holding M1
	if State.sprinting() or WeaponState.reloading() or WeaponState.chambering() then return end
	if not WC.holdingM1 or not WC.cycled then return end

	local freeLook = State.freeLook()
	local blocked = WeaponState.blocked()
	local fireMode = WeaponState.fireMode()

	local canFireShot = WC.canFire
		and not blocked
		and WeaponState.holdStance() == Enums.HoldStance.Ready
		and WC.IsLoaded()
		and fireMode > 0
		and (config.fireWithFreelook or not freeLook)
		and not WeaponState.equipping()

	if canFireShot then
		if not State.firstPerson() and not config.thirdPersonFiring then return end

		local currentStats = WC.GetCurrentWepStats()
		AnimationEvents.FireAnimRequested:Fire()
		WC.PerformRecoil(WeaponState.wepStats)

		WC.bulletsCurrentlyFired += 1
		WC.ejected = false

		if fireMode == Enums.FireModes.Semi or fireMode == Enums.FireModes.Manual or fireMode == Enums.FireModes.UBGL or (fireMode == Enums.FireModes.Burst and WC.bulletsCurrentlyFired >= currentStats.burstNumber) then
			WC.canFire = false
			WC.holdingM1 = false
		end
		
		WeaponState.RecoilFactor = math.clamp(WeaponState.RecoilFactor + WeaponState.wepStats.RecoilStepAmount,
			WeaponState.wepStats.MinRecoilFactor, WeaponState.wepStats.MaxRecoilFactor)

		WC.cycled = false
		local curModel = WeaponState.gunModel()

		if fireMode ~= Enums.FireModes.Manual and fireMode ~= Enums.FireModes.UBGL then
			WC.EjectShell()
		end

		if fireMode ~= Enums.FireModes.UBGL then
			local bulletHandlerPart = WeaponState.wepStats.bulletHandler and WeaponState.gunModel():FindFirstChild(WeaponState.wepStats.bulletHolder)
			if bulletHandlerPart then
				local bulletNumber = WeaponState.gunAmmo.MagAmmo.MaxValue - (WeaponState.gunAmmo.MagAmmo.Value - 1)
				local tempBulletPart = bulletHandlerPart:FindFirstChild("Bullet"..bulletNumber)
				if tempBulletPart then tempBulletPart.Transparency = 1 end
			end
		end

		local tempGunModel = WeaponState.gunModel()
		if not State.firstPerson() then tempGunModel = WC.GetThirdPersonGunModel() end

		local muzzleName = (fireMode == Enums.FireModes.UBGL) and "UBGLMuzzle" or "Muzzle"
		local muCh = WeaponState.attStats.muzzleChance or WeaponState.wepStats.muzzleChance
		if WeaponState.attStats.newMuzzleDevice then tempGunModel = tempGunModel[WeaponState.attStats.newMuzzleDevice] end
		
		bulletHandler.FireFX(WC.player, tempGunModel, muzzleName, muCh, fireMode == Enums.FireModes.UBGL)
		WC.PlayRepSound("Fire")

		if fireMode ~= Enums.FireModes.UBGL then
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
			if WeaponState.attStats.muzzleVelocityReplace then muVe = WeaponState.attStats.muzzleVelocityReplace end
			if WeaponState.attStats.muzzleVelocity then muVe *= WeaponState.attStats.muzzleVelocity end
			local bulletVelocity = (bulletDirection * muVe * 3.5)

			local tracerColor = nil
			local TrTi = currentStats.tracerTiming
			if TrTi and WeaponState.attStats.tracerTiming then TrTi = currentStats.tracerTiming end
			if fireMode ~= Enums.FireModes.UBGL and currentStats.tracers and WeaponState.gunAmmo.MagAmmo.Value % TrTi == 0 then
				tracerColor = WeaponState.attStats.tracerColor or currentStats.tracerColor
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
		if WeaponState.attStats.fireRate then cycleTime *= WeaponState.attStats.fireRate end

		if currentStats.projectile ~= "Bullet" then
			WC.SetProjectileTransparency(WeaponState.gunModel(), 1)
		end

		task.wait(60 / cycleTime)
		if not State.equippedTool() then return end

		if currentStats.autoChamber and fireMode == Enums.FireModes.Manual and not WeaponState.reloading() then
			WeaponState.holdStance(Enums.HoldStance.Ready)
			WeaponState.chambering(true)
		end
		WC.cycled = true
	else
		if not WC.IsLoaded() then
			if fireMode == Enums.FireModes.Manual and WeaponState.gunAmmo.MagAmmo.Value > 0 then
				WeaponState.holdStance(Enums.HoldStance.Ready)
				WeaponState.chambering(true)
				WC.holdingM1 = false
			end
		elseif WeaponState.wepStats.emptyCloseBolt then
			WC.repChamber:Fire()
			WC.MoveBolt(CFrame.new())
		end
	end
end

function WC.UpdateRender(dt)
	local adjust = dt * 60
	if not State.equippedTool() or WC.camera.CameraType ~= Enum.CameraType.Custom then return end

	--recoil logic
	WeaponState.RecoilCF = WeaponState.RecoilCF:Lerp(CFrame.new(),math.min(1, WeaponState.wepStats.PunchRecover * adjust))
	WeaponState.RecoilPos.t = WeaponState.RecoilCF.Position
	WeaponState.RecoilDir.t = WeaponState.RecoilCF.LookVector
	WeaponState.RecoilUp.t = WeaponState.RecoilCF.UpVector
	WeaponState.RecoilFactor = math.clamp(WeaponState.RecoilFactor - WeaponState.wepStats.RecoilRecoverPerSecond * dt,
		WeaponState.wepStats.MinRecoilFactor, WeaponState.wepStats.MaxRecoilFactor)

	local bipodPart = WeaponState.gunModel().Grip:FindFirstChild("Bipod")
	local bipodModel = WeaponState.gunModel()
	if WeaponState.attStats.Bipod and WeaponState.gunModel()[WeaponState.attStats.Bipod].Main:FindFirstChild("Bipod") then
		bipodPart = WeaponState.gunModel()[WeaponState.attStats.Bipod].Main.Bipod
		bipodModel = WeaponState.gunModel()[WeaponState.attStats.Bipod]
	end

	if bipodPart then
		local bipodRayParams = RaycastParams.new()
		bipodRayParams.FilterType = Enum.RaycastFilterType.Exclude
		bipodRayParams.FilterDescendantsInstances = WC.bipodRayIgnore
		bipodRayParams.RespectCanCollide = true
		local rayResult = workspace:Raycast(bipodPart.WorldCFrame.Position, Vector3.new(0,-1.5,0), bipodRayParams)
		WC.canBipod = rayResult ~= nil

		if WC.canBipod ~= WeaponState.bipodEnabled() then
			WeaponState.bipodEnabled(WC.canBipod)
		end
	end

end

function WC.OnKeyframeReached(animName, keyframeName, newAnim, animType)
	if WeaponState.gunModel().Grip:FindFirstChild(keyframeName) then WC.PlayRepSound(keyframeName) end
	if keyframeName == "MagIn" then
		if State.equippedTool() and (not State.equippedTool().Chambered.Value or WeaponState.wepStats.openBolt) and WeaponState.wepStats.autoChamber then
			WeaponState.reloading(true)
			AnimationEvents.StopAnimationRequested:Fire(animName, 0.4)
			AnimationEvents.BoltActionRequested:Fire(State.equippedTool().BoltReady.Value)
		end
		local bulletHandlerPart = WeaponState.wepStats.bulletHandler and WeaponState.gunModel():FindFirstChild(WeaponState.wepStats.bulletHolder)
		if bulletHandlerPart then
			for _, child in bulletHandlerPart:GetChildren() do
				if child:IsA("BasePart") and string.sub(child.Name, 1, 6) == "Bullet" then child.Transparency = 0 end
			end
		end
		WC.repReload:Fire()
		if WeaponState.wepStats.magType > 1 then newAnim.DidLoop:Once(function() AnimationEvents.StopAnimationRequested:Fire(animName) end) end
	elseif keyframeName == "ShellInsert" or keyframeName == "BulletInsert" then
		if WC.cancelReload then
			WC.cancelReload = false
			newAnim.Looped = false
			newAnim.Stopped:Once(function()
				if not State.equippedTool() then return end
				AnimationEvents.StopAnimationRequested:Fire(newAnim.Name)
				if not State.equippedTool().BoltReady.Value or WeaponState.wepStats.openBolt then
					AnimationEvents.BoltActionRequested:Fire(false)
				else
					WeaponState.reloading(false)
				end
			end)
		elseif WeaponState.gunAmmo.MagAmmo.Value + 1 >= WeaponState.gunAmmo.MagAmmo.MaxValue or WeaponState.gunAmmo.ArcadeAmmoPool.Value - 1 <= 0 then
			newAnim.DidLoop:Once(function()
				if not State.equippedTool() then return end
				AnimationEvents.StopAnimationRequested:Fire(newAnim.Name)
				if not State.equippedTool().BoltReady.Value or WeaponState.wepStats.operationType == 3 or WeaponState.wepStats.openBolt then
					AnimationEvents.BoltActionRequested:Fire(false)
				else
					WeaponState.reloading(false)
				end
			end)
		end
		local bulletHandlerPart = WeaponState.wepStats.bulletHolder and WeaponState.gunModel():FindFirstChild(WeaponState.wepStats.bulletHolder)
		if bulletHandlerPart then
			local bulletNumber = WeaponState.gunAmmo.MagAmmo.MaxValue - WeaponState.gunAmmo.MagAmmo.Value
			local tempBulletPart = bulletHandlerPart:FindFirstChild("Bullet"..bulletNumber)
			if tempBulletPart then tempBulletPart.Transparency = 0 end
		end
		WC.repReload:Fire()
	elseif keyframeName == "ClipInsertEnd" then
		local ammoNeeded = WeaponState.gunAmmo.MagAmmo.MaxValue - WeaponState.gunAmmo.MagAmmo.Value
		local clipSize = WeaponState.wepStats.clipSize or WeaponState.attStats.magazineCapacity or WeaponState.wepStats.magazineCapacity
		if ammoNeeded > 0 then
			AnimationEvents.StopAnimationRequested:Fire(newAnim.Name)
			AnimationEvents.ReloadActionRequested:Fire(ammoNeeded >= clipSize)
		end
	elseif keyframeName == "ClipInsert" then
		WC.repReload:Fire()
	elseif keyframeName == "SlideRelease" or keyframeName == "BoltClose" then
		WC.repChamber:Fire()
		WeaponState.reloading(false)
		WC.MoveBolt(CFrame.new(), true)
	elseif keyframeName == "SlidePull" and State.equippedTool() and State.equippedTool().Chambered.Value then
		WC.EjectShell()
	elseif keyframeName == "Switch" and not WeaponState.reloading() then
		WC.SwitchFireMode()
	elseif keyframeName == "MagGrab" then
		WC.SetProjectileTransparency(WeaponState.gunModel(), 0)
		WC.SetProjectileTransparency(WC.GetThirdPersonGunModel(), 0)
		WC.magGrab:Fire()
	elseif keyframeName == "BoltOpen" then
		WC.repBoltOpen:Fire()
		if not WC.ejected then WC.EjectShell() end
	end
end

function WC.OnAnimationStopped(animName, newAnim, animType)
	if animType == "Reload" then
		WeaponState.reloading(false)
		if State.equippedTool() and State.equippedTool().Chambered.Value then
			WC.SetProjectileTransparency(WeaponState.gunModel(), 0)
		end
	end
end

return WC
