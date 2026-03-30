local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")
local userInputService = game:GetService("UserInputService")
local debris = game:GetService("Debris")
local players = game:GetService("Players")
local tweenService = game:GetService("TweenService")
local testService = game:GetService("TestService")
local httpService = game:GetService("HttpService")

local assets = replicatedStorage.SPH_Assets
local modules = assets.Modules
local animations = assets.Animations
local player = players.LocalPlayer

local character = script.Parent.Parent
local humanoid:Humanoid = character:WaitForChild("Humanoid")
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local rootJoint --= humanoidRootPart:WaitForChild("RootJoint")
local neckJoint
local rigType -- DD_SPH: Added variable for ease of use
if humanoid.RigType == Enum.HumanoidRigType.R6 then
	rootJoint = humanoidRootPart:WaitForChild("RootJoint")
	neckJoint = character.Torso.Neck
	rigType = humanoid.RigType
else
	rootJoint = character.LowerTorso.Root -- DD_SPH: Root Motor6D is in LowerTorso instead of HRP
	neckJoint = character.Head.Neck -- DD_SPH: SPH v1.2.3 lists this as UpperTorso which is wrong
	rigType = humanoid.RigType
end
local camera = workspace.CurrentCamera
if camera.CameraSubject ~= humanoid then camera.CameraSubject = humanoid end
camera.CameraType = Enum.CameraType.Custom
if camera:FindFirstChild("WeaponRig") then camera.WeaponRig:Destroy() end

local defaultFOV = camera.FieldOfView

local weldMod = require(modules.WeldMod)
local bridgeNet = require(modules.BridgeNet)
local viewMod = require(modules.ViewMod)
local springMod = require(modules.SpringModule)
local hitFX = require(modules.HitFX)
local shellEjection = require(modules.ShellEjection)
local bulletHandler = require(modules.BulletHandler)
local callbacks = require(assets.Mods)
local InputController = require(script.Parent:WaitForChild("Controllers"):WaitForChild("InputController"))

bulletHandler.Initialize(player)

local config = require(assets.GameConfig)
local warnPrefix = "【 SPEARHEAD 】 "
humanoid.WalkSpeed = config.walkSpeed

local sphWorkspace = workspace:WaitForChild("SPH_Workspace")
local shellFolder = sphWorkspace:WaitForChild("Shells")

local rayParams = RaycastParams.new()
rayParams.IgnoreWater = true
rayParams.RespectCanCollide = true
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.FilterDescendantsInstances = {character,camera,shellFolder}

local swaySpring = springMod.new()
local moveSpring = springMod.new()
local recoilSpring = springMod.new()
local gunRecoilSpring = springMod.new()

local bodyAnimRequest = bridgeNet.CreateBridge("BodyAnimRequest")
local switchWeapon = bridgeNet.CreateBridge("SwitchWeapon")
local playerFire = bridgeNet.CreateBridge("PlayerFire")
local playSound = bridgeNet.CreateBridge("PlaySound")
local repReload = bridgeNet.CreateBridge("Reload")
--local bulletHit = bridgeNet.CreateBridge("BulletHit")
local repChamber = bridgeNet.CreateBridge("PlayerChamber")
local moveBolt = bridgeNet.CreateBridge("MoveBolt")
local switchFireMode = bridgeNet.CreateBridge("SwitchFireMode")
local playCharSound = bridgeNet.CreateBridge("PlayCharacterSound")
local playerDropGun = bridgeNet.CreateBridge("PlayerDropGun")
local playerToggleAttachment = bridgeNet.CreateBridge("PlayerToggleAttachment")
local repBoltOpen = bridgeNet.CreateBridge("RepBoltOpen")
local magGrab = bridgeNet.CreateBridge("MagGrab")
local playerLean = bridgeNet.CreateBridge("PlayerLean")

local fpThreshold = 0.6

local rollAngle = 0
local cameraRollAngle = 0
local targetWalkSpeed = config.walkSpeed
local tempWalkSpeed = targetWalkSpeed

local depthOfField = game.Lighting:FindFirstChild("SPH_DoF") or (config.blurEffects and Instance.new("DepthOfFieldEffect",game.Lighting))
if depthOfField then depthOfField.Name = "SPH_DoF" end

local holdingM1 = false
local cycled = true
local firstPerson = false
local equipping = false
local dead = false
local canFire = true
local viewmodelVisible = false
local blocked = false
local holdStance = 0
local holdAnim
local laserEnabled = false
local flashlightEnabled = false
local canBipod = false -- DD_SPH: Bipod
local bipodEnabled = false -- DD_SPH: Bipod
local bipodRayIgnore = {character}
local vehicleSeated = false
local ejected = true
local cancelReload = false
local chambering = false
local sprintHeld = false
local aimHeld = false

--local fireModes = {
--	Safe = 0,
--	Semi = 1,
--	Auto = 2,
--	Burst = 3,
--	Manual = 4
--}
--local curFireMode
--local bulletsCurrentlyFired = 0

-- [UBGL START] - Fire Modes with UBGL Integration
local fireModes = {
	Safe = 0,
	Semi = 1,
	Auto = 2,
	Burst = 3,
	UBGL = 4, -- Under Barrel Grenade Launcher
	Manual = 5 -- Moved to 5 to accommodate UBGL
}
local curFireMode
local bulletsCurrentlyFired = 0

-- UBGL-specific variables
local ubglAmmo = nil -- Separate ammo pool for UBGL
local currentWepStats = nil -- Current weapon stats (switches between primary and UBGL)
-- [UBGL END] - Fire Modes with UBGL Integration

local equipped, wepStats, sprinting, gunModel, gunAmmo, reloading, aiming, offset, freeLook, moving
local freeLookOffset = CFrame.new()
local freeLookRotation = CFrame.new()
local aimingOffset = CFrame.new()
local aimTarget = CFrame.new()
local aimFOVTarget = camera.FieldOfView

local headRotationEventCooldown = 0

local pushbackOffset = 0

local hipRotation = Vector2.zero

local storageCFrame = CFrame.new(1000000,0,0) -- This is used for moving the viewmodel super far away.
-- Doing this to the viewmodel allows animations to be loaded, played, etc, while still having it out of view.

-- DD_SPH: Get the character's rig type to determine what animation folder to load from.
if rigType == Enum.HumanoidRigType.R15 then
	animations = assets.Animations.R15
else
	animations = assets.Animations.R6
end
-- </DD_SPH>

-- Preload movement animations
local stance = 0
local crouchIdleAnim:AnimationTrack = humanoid.Animator:LoadAnimation(animations.Crouch_Idle)
crouchIdleAnim.Looped = true
crouchIdleAnim.Priority = Enum.AnimationPriority.Idle

local crouchMoveAnim:AnimationTrack = humanoid.Animator:LoadAnimation(animations.Crouch_Move)
crouchMoveAnim.Looped = true
crouchMoveAnim.Priority = Enum.AnimationPriority.Movement

local proneIdleAnim:AnimationTrack = humanoid.Animator:LoadAnimation(animations.Prone_Idle)
proneIdleAnim.Looped = true
proneIdleAnim.Priority = Enum.AnimationPriority.Idle

local proneMoveAnim:AnimationTrack = humanoid.Animator:LoadAnimation(animations.Prone_Move)
proneMoveAnim.Looped = true
proneMoveAnim.Priority = Enum.AnimationPriority.Movement

local moveAnim

local loadedAnims = {}

local xHead, yHead, zHead
local cameraOffsetTarget = Vector3.zero

local defaultCameraMode = player.CameraMode

local sights = {}

local sightIndex = 1

local lean = 0
local cameraLeanRotation = 0
-- local aimSensitivity = player:GetAttribute("SavedAimSensitivity") or config.defaultAimSensitivity
local aimSensitivity = 1
local proneViewmodelOffset = 0

local laserDotUI = assets.HUD.LaserDotUI:Clone()
local laserDotPoint = Instance.new("Attachment")
laserDotPoint.Parent = workspace.Terrain
laserDotUI.Enabled = false
laserDotUI.Parent = laserDotPoint
--laserDotUI.AlwaysOnTop = true

local laserBeamFP = Instance.new("Beam")
laserBeamFP.Attachment1 = laserDotPoint
laserBeamFP.LightInfluence = 0
laserBeamFP.Brightness = 3
laserBeamFP.Segments = 1
laserBeamFP.Width0 = 0.02
laserBeamFP.Width1 = 0.02
laserBeamFP.FaceCamera = true
laserBeamFP.Transparency = NumberSequence.new(0.5)
laserBeamFP.Name = "FirstPersonLaser"
laserBeamFP.Parent = laserDotPoint
laserBeamFP.Enabled = false

local laserBeamTP = laserBeamFP:Clone()
laserBeamTP.Name = "ThirdPersonLaser"
laserBeamTP.Parent = laserDotPoint
laserBeamTP.Enabled = false

-- Disable default death sound
if humanoidRootPart:FindFirstChild("Died") then
	humanoidRootPart.Died.Volume = 0
end

-- Unlock the camera if lock first person for guns is enabled
if config.lockFirstPerson then
	player.CameraMode = Enum.CameraMode.Classic
end

-- Create new viewmodel
rig = viewMod.RigModel(player)

-- Create fake arms
--local lArm = rig["Left Arm"]
--local rArm = rig["Right Arm"]
--lArm.Color = character["Left Arm"].Color
--rArm.Color = character["Right Arm"].Color

--for _, part in ipairs(rig:GetDescendants()) do
--	if part.Name == "Skin" then
--		if part.Parent.Name == "Left Arm" then
--			part.Color = character["Left Arm"].Color
--		elseif part.Parent.Name == "Right Arm" then
--			part.Color = character["Right Arm"].Color
--		end
--	end
--end

if rigType == Enum.HumanoidRigType.R6 then -- DD_SPH: Easy coloring
	local lArm = rig["Left Arm"]
	local rArm = rig["Right Arm"]
	lArm.Color = character["Left Arm"].Color
	rArm.Color = character["Right Arm"].Color

	for _, part in ipairs(rig:GetDescendants()) do
		if part.Name == "Skin" then
			if part.Parent.Name == "Left Arm" then
				part.Color = character["Left Arm"].Color
			elseif part.Parent.Name == "Right Arm" then
				part.Color = character["Right Arm"].Color
			end
		end
	end
else
	local bodyparts = {"LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand"} -- DD_SPH: List of bodyparts for easy iterating
	for i = 1, #bodyparts do
		rig[bodyparts[i]].Color = character[bodyparts[i]].Color
	end
end -- </DD_SPH>

-- Set up an animator
local vmHuman = Instance.new("Humanoid",rig)

vmHuman.RigType = rigType -- DD_SPH: sets humanoid rigtype in rig to match player rigtype

for _, state in ipairs(Enum.HumanoidStateType:GetEnumItems()) do
	if state == Enum.HumanoidStateType.None then continue end -- The 'None' state needs to be skipped because it cannot be disabled
	vmHuman:SetStateEnabled(state,false)
end

local vmAnimator = Instance.new("Animator",vmHuman)
local vmShirt = Instance.new("Shirt",rig)
local animBase = rig.AnimBase
animBase.CFrame = storageCFrame

rig.Parent = camera

local weaponRig = character:FindFirstChild("WeaponRig") or character:WaitForChild("WeaponRig")
local characterAnimator:Animator = weaponRig:WaitForChild("AnimationController").Animator
local lastGunModel -- DD_SPH: Catch against reload swapping (starting reload on one gun and finishing it on another)

-- DD_SPH Gunsmith
local gunsmith = require(modules.Gunsmith)
local attStats = gunsmith.attStats

--local function PlayRepSound(soundName)
--	if not dead then
--		local soundToPlay = gunModel.Grip:FindFirstChild(soundName)
--		if soundToPlay and equipped then
--			if firstPerson then
--				soundToPlay:Play()
--			else
--				local soundToPlay = soundToPlay:Clone()
--				soundToPlay.Parent = humanoidRootPart
--				soundToPlay:Play()
--				debris:AddItem(soundToPlay,soundToPlay.TimeLength)
--			end
--			playSound:Fire(soundName, firstPerson)
--		end
--	end
--end

-- [UBGL START] - Enhanced Sound System for UBGL
local function PlayRepSound(soundName)
	if not dead and wepStats then -- Add wepStats nil check
		local soundToPlay
		-- Check if we're in UBGL mode and need to use UBGL sounds
		if curFireMode == fireModes.UBGL and wepStats.hasUBGL then
			-- Try to find UBGL-specific sound first
			soundToPlay = gunModel.Grip:FindFirstChild("UBGL_" .. soundName)
			if not soundToPlay then
				-- Fallback to regular sound
				soundToPlay = gunModel.Grip:FindFirstChild(soundName)
				-- DD_SPH Gunsmith: New Fire Sound for client
				if attStats.newFireSound and soundName == "Fire" then
					soundToPlay = gunModel[attStats.newMuzzleDevice].Main.Fire
				end
				-- </DD_SPH>
			end
		else
			soundToPlay = gunModel.Grip:FindFirstChild(soundName)
			-- DD_SPH Gunsmith: New Fire Sound for client
			if attStats.newFireSound and soundName == "Fire" then
				soundToPlay = gunModel[attStats.newMuzzleDevice].Main.Fire
			end
			-- </DD_SPH>
		end

		if soundToPlay and equipped then
			if firstPerson then
				soundToPlay:Play()
			else
				local soundToPlay = soundToPlay:Clone()
				soundToPlay.Parent = humanoidRootPart
				soundToPlay:Play()
				debris:AddItem(soundToPlay,soundToPlay.TimeLength)
			end
			playSound:Fire(soundName, firstPerson)
		end
	end
end
-- [UBGL END] - Enhanced Sound System for UBGL

--local function IsLoaded()
--	return not wepStats.openBolt and equipped.Chambered.Value or wepStats.openBolt and gunAmmo.MagAmmo.Value > 0
--end

-- [UBGL START] - UBGL Helper Functions
-- Get current weapon stats based on fire mode
local function GetCurrentWepStats()
	if curFireMode == fireModes.UBGL and wepStats.hasUBGL then
		return wepStats.getStatsForMode(4)
	else
		return wepStats
	end
end

-- Check if weapon is loaded based on current fire mode
local function IsLoaded()
	local currentStats = GetCurrentWepStats()
	if curFireMode == fireModes.UBGL and wepStats.hasUBGL then
		-- UBGL uses separate ammo pool
		return ubglAmmo and ubglAmmo.Value > 0
	else
		-- Primary weapon ammo
		return not currentStats.openBolt and equipped.Chambered.Value or currentStats.openBolt and gunAmmo.MagAmmo.Value > 0
	end
end

-- Get appropriate muzzle point based on fire mode
local function GetMuzzlePoint(gunModel)
	if curFireMode == fireModes.UBGL and wepStats.hasUBGL then
		-- Use UBGL muzzle
		local ubglMuzzle = gunModel.Grip:FindFirstChild("UBGLMuzzle")
		if ubglMuzzle then
			return ubglMuzzle
		end
	end
	-- Default to primary weapon muzzle
	return gunModel.Grip.Muzzle
end
-- [UBGL END] - UBGL Helper Functions

local function PlayCharSound(soundType)
	local soundFolder = assets.Sounds:FindFirstChild(soundType)
	if soundFolder then
		local soundList = soundFolder:GetChildren()
		local newSound = soundList[math.random(#soundList)]:Clone()
		newSound.Parent = humanoidRootPart
		newSound:Play()
		debris:AddItem(newSound,newSound.TimeLength)
		playCharSound:Fire(soundType)
	end
end

local function ChangeLean(newLean)
	if not config.canLean then return end -- Return if the player can't lean
	if newLean ~= lean then PlayCharSound("Lean") end
	lean = newLean
	playerLean:Fire(newLean)
end

local function MoveBolt(direction:CFrame,silent:boolean)
	bulletHandler.MoveBolt(gunModel,wepStats,direction,gunAmmo.MagAmmo.Value)
	bulletHandler.MoveBolt(weaponRig.Weapon:FindFirstChildWhichIsA("Model"),wepStats,direction,gunAmmo.MagAmmo.Value)
	if gunAmmo.MagAmmo.Value <= 0 and not silent then
		PlayRepSound("Empty")
	end
	moveBolt:Fire(direction,gunAmmo.MagAmmo.Value)
end

local function ToggleADS(toggle)
	--if wepStats and wepStats.ADSEnabled then
	if (wepStats and wepStats.ADSEnabled) or (attStats and attStats.ADSEnabled) then -- DD_SPH: checks for attstats ADS
		local ADSTween
		--if wepStats.aimTime then
		--	ADSTween = TweenInfo.new(wepStats.aimTime / 20,Enum.EasingStyle.Linear,Enum.EasingDirection.Out,0,false,wepStats.aimTime / 20)
		--else
		--	ADSTween = TweenInfo.new(0.2,Enum.EasingStyle.Linear,Enum.EasingDirection.Out,0,false,0.2)
		--end

		-- DD_SPH Gunsmith: Adjusting aim time
		local aimingTime
		if wepStats.aimTime then
			aimingTime = wepStats.aimTime / 20
		else
			aimingTime = 0.2
		end
		if attStats.aimTime then
			aimingTime *= attStats.aimTime
		end
		ADSTween = TweenInfo.new(aimingTime,Enum.EasingStyle.Linear,Enum.EasingDirection.Out,0,false,aimingTime)
		-- </DD_SPH>

		if not toggle then
			for _, child in pairs(gunModel:GetDescendants()) do -- DD_SPH Gunsmith: Changed to GetDescendants to cover attachments
				if child.Name == "REG" then
					tweenService:Create(child, ADSTween, {Transparency = 0}):Play()
				elseif child.Name == "ADS" then
					tweenService:Create(child, ADSTween, {Transparency = 1}):Play()
				end
			end
		elseif toggle then
			for _, child in pairs(gunModel:GetDescendants()) do -- DD_SPH Gunsmith: Changed to GetDescendants to cover attachments
				if child.Name == "REG" then
					tweenService:Create(child, ADSTween, {Transparency = 1}):Play()
				elseif child.Name == "ADS" then
					tweenService:Create(child, ADSTween, {Transparency = 0}):Play()
				end
			end
		end
	end
end

local function ToggleBipod(bipodModel, toggle)
	for i, bipObject in pairs(bipodModel:GetChildren()) do
		if bipObject.Name == "Bipod_On" then
			if toggle then
				bipObject.Transparency = 0
			else
				bipObject.Transparency = 1
			end
		end
		if bipObject.Name == "Bipod_Off" then
			if toggle then
				bipObject.Transparency = 1
			else
				bipObject.Transparency = 0
			end
		end
	end
end

local function EjectShell()
	ejected = true
	if wepStats.shellEject then
		if firstPerson then
			shellEjection.ejectShell(player,equipped,gunModel)
		else
			shellEjection.ejectShell(player,equipped,weaponRig.Weapon:FindFirstChildWhichIsA("Model"))
		end
	end
end

local function GetThirdPersonGunModel()
	return weaponRig.Weapon:FindFirstChildWhichIsA("Model")
end

-- Stop an animation track that has already been loaded
local function StopAnimation(animName:string, transTime:number)
	if loadedAnims[animName] then
		if transTime then
			loadedAnims[animName]:Stop(transTime)
			loadedAnims[animName.."ThirdPerson"]:Stop(transTime)
		else
			loadedAnims[animName]:Stop()
			loadedAnims[animName.."ThirdPerson"]:Stop()
		end
	else
		--warn("Attempted to stop animation '".. animName.. "', animation has not been loaded.")
	end
end

local function SwitchFireMode()
	repeat
		curFireMode += 1
		if curFireMode > 4 then curFireMode = 0 break end
	until wepStats.fireSwitch[curFireMode]
	switchFireMode:Fire(curFireMode)
end

-- Play an animation or load it if it's not already
local function PlayAnimation(animName:string, parameters:table, animType:string, preload)
	parameters = parameters or {}
	local animToPlay, tpAnim
	if loadedAnims[animName] then
		animToPlay = loadedAnims[animName]
		tpAnim = loadedAnims[animName.."ThirdPerson"]
	elseif animName and animations:FindFirstChild(animName) then
		local newAnim = vmAnimator:LoadAnimation(animations[animName])
		newAnim.Looped = parameters.looped or false
		newAnim.Priority = parameters.priority or Enum.AnimationPriority.Action
		loadedAnims[animName] = newAnim

		local thirdPersonAnim:AnimationTrack = characterAnimator:LoadAnimation(animations[animName])
		thirdPersonAnim.Looped = parameters.looped or false
		thirdPersonAnim.Priority = parameters.priority or Enum.AnimationPriority.Action
		loadedAnims[animName.."ThirdPerson"] = thirdPersonAnim

		-- Keyframe names
		newAnim.KeyframeReached:Connect(function(keyframeName)

			if gunModel.Grip:FindFirstChild(keyframeName) then
				PlayRepSound(keyframeName)
			end

			if keyframeName == "MagIn" then

				-- Auto chamber code
				if equipped and (not equipped.Chambered.Value or wepStats.openBolt) and wepStats.autoChamber then
					reloading = true
					local animNameToPlay
					if equipped.BoltReady.Value then
						animNameToPlay = wepStats.boltChamber
					else
						animNameToPlay = wepStats.boltClose
					end
					StopAnimation(animName,0.4)
					PlayAnimation(animNameToPlay,{priority = Enum.AnimationPriority.Action2,transSpeed = 0.05})
				end

				-- Bullet visibility
				local bulletHandlerPart = wepStats.bulletHandler and gunModel:FindFirstChild(wepStats.bulletHolder)
				if bulletHandlerPart then
					for _, child in bulletHandlerPart:GetChildren() do
						if child:IsA("BasePart") and string.sub(child.Name, 1, 6) == "Bullet" then
							child.Transparency = 0
						end
					end
				end

				repReload:Fire()
				--reloading = false

				if wepStats.magType > 1 then
					newAnim.DidLoop:Once(function()
						StopAnimation(animName)
					end)
				end
			elseif keyframeName == "ShellInsert" or keyframeName == "BulletInsert" then
				if cancelReload then -- Should reloading be canceled?
					cancelReload = false
					newAnim.Looped = false
					newAnim.Stopped:Once(function()
						if not equipped then return end
						StopAnimation(newAnim.Name)
						if not equipped.BoltReady.Value or wepStats.openBolt then
							PlayAnimation(wepStats.boltClose,{priority = Enum.AnimationPriority.Action2})
						else
							reloading = false
						end
					end)
				elseif gunAmmo.MagAmmo.Value + 1 >= gunAmmo.MagAmmo.MaxValue or gunAmmo.ArcadeAmmoPool.Value - 1 <= 0 then
					newAnim.DidLoop:Once(function()
						if not equipped then return end
						StopAnimation(newAnim.Name)
						if not equipped.BoltReady.Value or wepStats.operationType == 3 or wepStats.openBolt then
							PlayAnimation(wepStats.boltClose,{priority = Enum.AnimationPriority.Action2})
						else
							reloading = false
						end
					end)
				elseif wepStats.openBolt then
					--PlayAnimation(wepStats.boltClose,{priority = Enum.AnimationPriority.Action2})
					--print(gunAmmo.MagAmmo.Value, gunAmmo.ArcadeAmmoPool.Value)
				end

				-- Bullet visibility
				local bulletHandlerPart = wepStats.bulletHolder and gunModel:FindFirstChild(wepStats.bulletHolder)
				if bulletHandlerPart then
					local bulletNumber = gunAmmo.MagAmmo.MaxValue - gunAmmo.MagAmmo.Value
					local tempBulletPart = bulletHandlerPart:FindFirstChild("Bullet"..bulletNumber)
					if tempBulletPart then
						tempBulletPart.Transparency = 0
					end
				end

				repReload:Fire()
			elseif keyframeName == "ClipInsertEnd" then
				local ammoNeeded = gunAmmo.MagAmmo.MaxValue - gunAmmo.MagAmmo.Value
				--local clipSize = wepStats.clipSize or wepStats.magazineCapacity
				local clipSize = wepStats.clipSize or attStats.magazineCapacity or wepStats.magazineCapacity -- DD_SPH Gunsmith
				--if ammoNeeded > 0 then
				--	StopAnimation(newAnim.Name)
				--	if ammoNeeded >= clipSize then
				--		PlayAnimation(wepStats.clipReloadAnim,{looped = true,speed = wepStats.reloadSpeedModifier,priority = Enum.AnimationPriority.Action2,transSpeed = 0.17})
				--	else
				--		PlayAnimation(wepStats.reloadAnim,{speed = wepStats.reloadSpeedModifier,priority = Enum.AnimationPriority.Action2,transSpeed = 0.17},"Reload")
				--	end
				--end

				local animSpeed = wepStats.reloadSpeedModifier -- DD_SPH Gunsmith
				if attStats.reloadSpeedModifier then animSpeed *= attStats.reloadSpeedModifier end

				if ammoNeeded > 0 then
					StopAnimation(newAnim.Name)
					if ammoNeeded >= clipSize then
						PlayAnimation(wepStats.clipReloadAnim,{looped = true,speed = animSpeed,priority = Enum.AnimationPriority.Action2,transSpeed = 0.17}) -- DD_SPH Gunsmith: added animSpeed
					else
						PlayAnimation(wepStats.reloadAnim,{speed = animSpeed,priority = Enum.AnimationPriority.Action2,transSpeed = 0.17},"Reload") -- DD_SPH Gunsmith: added animSpeed
					end
				end

				--StopAnimation(newAnim.Name)
				--PlayAnimation(wepStats.reloadAnim,{speed = wepStats.reloadSpeedModifier,priority = Enum.AnimationPriority.Action2,transSpeed = 0.17},"Reload")
				--PlayAnimation(wepStats.clipReloadAnim,{looped = true,speed = wepStats.reloadSpeedModifier,priority = Enum.AnimationPriority.Action2,transSpeed = 0.17})
			elseif keyframeName == "ClipInsert" then
				repReload:Fire()
			elseif keyframeName == "SlideRelease" or keyframeName == "BoltClose" then
				repChamber:Fire()
				reloading = false
				MoveBolt(CFrame.new(),true)
			elseif keyframeName == "SlidePull" and equipped.Chambered.Value then
				EjectShell()
			elseif keyframeName == "Equip" then
				--equipping = false
				--if firstPerson then viewmodelVisible = true end

				--local projectile = gunModel:FindFirstChild(wepStats.projectile)
				--if not IsLoaded() and projectile and wepStats.projectile ~= "Bullet" then
				--	projectile.LocalTransparencyModifier = 1
				--	for _, child in ipairs(projectile:GetDescendants()) do
				--		if child:IsA("BasePart") then
				--			child.LocalTransparencyModifier = 1
				--		end
				--	end
				--end
			elseif keyframeName == "Switch" and not reloading then
				SwitchFireMode()
			elseif keyframeName == "MagGrab" then
				if gunModel and wepStats.projectile ~= "Bullet" and gunModel:FindFirstChild(wepStats.projectile) then
					local projectile = gunModel:FindFirstChild(wepStats.projectile)
					projectile.LocalTransparencyModifier = 0
					for _, child in ipairs(projectile:GetDescendants()) do
						if child:IsA("BasePart") then
							child.LocalTransparencyModifier = 0
						end
					end
					local thirdPersonGunModel = GetThirdPersonGunModel()
					local projectile = thirdPersonGunModel:FindFirstChild(wepStats.projectile)
					projectile.LocalTransparencyModifier = 0
					for _, child in ipairs(projectile:GetDescendants()) do
						if child:IsA("BasePart") then
							child.LocalTransparencyModifier = 0
						end
					end
					magGrab:Fire()
				end
			elseif keyframeName == "BoltOpen" then
				repBoltOpen:Fire()
				if not ejected then
					EjectShell()
				end
			end
		end)

		newAnim.Stopped:Connect(function()
			if animType == "Equip" then
				--equipping = false
				--if firstPerson then viewmodelVisible = true end
			elseif animType == "Reload" then
				reloading = false
				if wepStats and gunModel and gunModel:FindFirstChild(wepStats.projectile) and equipped.Chambered.Value then
					local projectile = gunModel:FindFirstChild(wepStats.projectile)
					projectile.LocalTransparencyModifier = 0
					for _, child in ipairs(projectile:GetDescendants()) do
						if child:IsA("BasePart") then
							child.LocalTransparencyModifier = 0
						end
					end
				end
			end
		end)

		--if string.find(animName, "Reload") and newAnim.Looped then
		--	newAnim.DidLoop:Connect(function()
		--		if 
		--	end)
		--end

		--repeat task.wait() until newAnim.Length > 0
		animToPlay = newAnim
		tpAnim = thirdPersonAnim
	end

	if animToPlay and not preload then
		animToPlay:Play(parameters.transSpeed or 0)
		animToPlay:AdjustSpeed(parameters.speed or 1)
		tpAnim:Play(parameters.transSpeed or 0)
		tpAnim:AdjustSpeed(parameters.speed or 1)
	end

	return animToPlay
end

local function ChangeHoldStance(newStance)
	if aiming then return end
	if holdStance == newStance and holdAnim then
		StopAnimation(holdAnim.Name, 0.3)
		holdAnim = nil
		holdStance = 0
	else
		holdStance = newStance

		if holdAnim then
			StopAnimation(holdAnim.Name, 0.3)
		end

		local animToPlay
		if holdStance == 1 and wepStats.holdUpAnim then
			animToPlay = wepStats.holdUpAnim
		elseif holdStance == 2 and wepStats.patrolAnim then
			animToPlay = wepStats.patrolAnim
		elseif holdStance == 3 and wepStats.holdDownAnim then
			animToPlay = wepStats.holdDownAnim
		end

		if animToPlay then
			holdAnim = PlayAnimation(animToPlay,{looped = true, priority = Enum.AnimationPriority.Action,transSpeed = 0.3})
			holdAnim:Play()
		elseif holdAnim then
			holdAnim = nil
		end
	end
end

local function ChamberAnim()
	local animNameToPlay
	if equipped.BoltReady.Value or curFireMode == fireModes.Manual then
		animNameToPlay = wepStats.boltChamber
	else
		animNameToPlay = wepStats.boltClose
	end

	if animNameToPlay then
		reloading = true
		chambering = true
		ChangeHoldStance(0)

		local playingAnim:AnimationTrack = PlayAnimation(animNameToPlay,{priority = Enum.AnimationPriority.Action2,transSpeed = 0.05})
		playingAnim.Stopped:Once(function()
			chambering = false
		end)
	end
end

local function IdleAnim()
	PlayAnimation(wepStats.idleAnim,{looped = true, priority = Enum.AnimationPriority.Idle})
end

local function EquipAnim()
	--equipping = true
	PlayAnimation(wepStats.equipAnim,{priority = Enum.AnimationPriority.Action2},"Equip")

	task.wait(0.1)
	if firstPerson then viewmodelVisible = true end
	if not wepStats then return end -- DD_SPH: catching against errors
	local projectile = gunModel:FindFirstChild(wepStats.projectile)
	if (wepStats.openBolt or not equipped.Chambered.Value) and projectile and wepStats.projectile ~= "Bullet" then
		projectile.LocalTransparencyModifier = 1
		for _, child in ipairs(projectile:GetDescendants()) do
			if child:IsA("BasePart") then
				child.LocalTransparencyModifier = 1
			end
		end
	end
end

local function ReloadAnim()
	if not equipped then return end

	cancelReload = false

	ChangeHoldStance(0)
	reloading = true

	local animSpeed = wepStats.reloadSpeedModifier -- DD_SPH gunsmith: Setting animspeed based on attstats
	if attStats.reloadSpeedModifier then animSpeed *= attStats.reloadSpeedModifier end

	-- [UBGL START] - UBGL Reload System
	-- Check if we're in UBGL mode
	if curFireMode == fireModes.UBGL and wepStats.hasUBGL then
		-- UBGL reload - simple single grenade reload
		local ubglStats = wepStats.getStatsForMode(4)
		if ubglStats.reloadAnim then
			PlayAnimation(ubglStats.reloadAnim,{speed = animSpeed,priority = Enum.AnimationPriority.Action2,transSpeed = 0.17},"Reload") -- DD_SPH gunsmith: Originally used wepstats reloadspeedmodifier
		else
			-- Fallback to primary weapon reload if no UBGL reload animation
			PlayAnimation(wepStats.reloadAnim,{speed = animSpeed,priority = Enum.AnimationPriority.Action2,transSpeed = 0.17},"Reload") -- DD_SPH gunsmith: Originally used wepstats reloadspeedmodifier
		end
		return
	end
	-- [UBGL END] - UBGL Reload System


	if wepStats.operationType == 3 or (wepStats.operationType == 2 and gunAmmo.MagAmmo.Value <= 0 and not equipped.Chambered.Value) then
		local boltOpenTrack = PlayAnimation(wepStats.boltOpen,{speed = animSpeed, priority = Enum.AnimationPriority.Action2, transSpeed = 0.17}) -- DD_SPH gunsmith: Originally used wepstats reloadspeedmodifier
		if not boltOpenTrack then
			warn(warnPrefix.."To use operation type "..wepStats.operationType..", a 'boltOpen' animation is required.")
			reloading = false
			return
		end
		boltOpenTrack.Stopped:Once(function()
			if wepStats.magType == 3
				--and (gunAmmo.MagAmmo.MaxValue - gunAmmo.MagAmmo.Value) >= (wepStats.clipSize or wepStats.magazineCapacity)
				--and gunAmmo.ArcadeAmmoPool.Value >= (wepStats.clipSize or wepStats.magazineCapacity) then then
				and (gunAmmo.MagAmmo.MaxValue - gunAmmo.MagAmmo.Value) >= (wepStats.clipSize or attStats.magazineCapacity or wepStats.magazineCapacity)
				and gunAmmo.ArcadeAmmoPool.Value >= (wepStats.clipSize or attStats.magazineCapacity or wepStats.magazineCapacity) then
				-- Clip insert
				local clipReloadTrack = PlayAnimation(wepStats.clipReloadAnim,{looped = true,speed = animSpeed,priority = Enum.AnimationPriority.Action2,transSpeed = 0.17}) -- DD_SPH gunsmith: Originally used wepstats reloadspeedmodifier
				--clipReloadTrack.Stopped:Once(function()
				--	if gunAmmo.MagAmmo.Value + 1 < gunAmmo.MagAmmo.MaxValue and gunAmmo.ArcadeAmmoPool.Value > 0 then
				--		ReloadAnim()
				--	end
				--end)
				--clipReloadTrack.Stopped:Connect(function()

				--end)
			else
				-- Bullet insert
				if lastGunModel and lastGunModel.Name ~= gunModel.Name then return end -- DD_SPH: Check against reload swapping
				local bulletInsert = PlayAnimation(wepStats.reloadAnim,{speed = animSpeed,priority = Enum.AnimationPriority.Action2,transSpeed = 0.17,looped = true},"Reload") -- DD_SPH gunsmith: Originally used wepstats reloadspeedmodifier
				if wepStats.magType > 1 then bulletInsert.Looped = true end
			end
		end)
	else
		PlayAnimation(wepStats.reloadAnim,{speed = animSpeed,priority = Enum.AnimationPriority.Action2,transSpeed = 0.17},"Reload") -- DD_SPH gunsmith: Originally used wepstats reloadspeedmodifier
	end
end

-- Makes the viewmodel visible and refreshes its appearance
local function RefreshViewmodel()
	if firstPerson and not equipping then
		viewmodelVisible = true
	end

	local plrShirt = character:FindFirstChildWhichIsA("Shirt")
	if plrShirt then vmShirt.ShirtTemplate = plrShirt.ShirtTemplate end

	--lArm.Color = character["Left Arm"].Color
	--rArm.Color = character["Right Arm"].Color

	--for _, part in ipairs(rig:GetDescendants()) do
	--	if part.Name == "Skin" then
	--		if part.Parent.Name == "Left Arm" then
	--			part.Color = character["Left Arm"].Color
	--		elseif part.Parent.Name == "Right Arm" then
	--			part.Color = character["Right Arm"].Color
	--		end
	--	end
	--end

	if rigType == Enum.HumanoidRigType.R6 then -- DD_SPH: Easy coloring
		local lArm = rig["Left Arm"]
		local rArm = rig["Right Arm"]
		lArm.Color = character["Left Arm"].Color
		rArm.Color = character["Right Arm"].Color

		for _, part in ipairs(rig:GetDescendants()) do
			if part.Name == "Skin" then
				if part.Parent.Name == "Left Arm" then
					part.Color = character["Left Arm"].Color
				elseif part.Parent.Name == "Right Arm" then
					part.Color = character["Right Arm"].Color
				end
			end
		end
	else
		local bodyparts = {"LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand"} -- DD_SPH: List of bodyparts for easy iterating
		for i = 1, #bodyparts do
			rig[bodyparts[i]].Color = character[bodyparts[i]].Color
		end
	end -- </DD_SPH>

	IdleAnim()

	if callbacks.onViewmodelRefresh then callbacks.onViewmodelRefresh(player,rig) end
end

-- Remove rig and reset head orientation
local function ResetHead()
	viewmodelVisible = false
end

local function GetSineOffset(addition:number)
	return math.sin(tick() * addition * 1.3) * 0.3
end

local function LerpNumber(number:number, target:number, speed:number)
	return number + (target-number) * speed
end

local function ToggleAiming(toggle)
	character:SetAttribute("Aiming", toggle)
	if toggle then
		ChangeHoldStance(0)
		aiming = true
		--if wepStats.ADSEnabled and wepStats.ADSEnabled[sightIndex] then
		if (attStats.ADSEnabled and attStats.ADSEnabled[sightIndex]) or (wepStats.ADSEnabled and wepStats.ADSEnabled[sightIndex]) then -- DD_SPH Gunsmith: ADS enabling
			ToggleADS(true)
		else
			ToggleADS(false)
		end
		userInputService.MouseDeltaSensitivity = aimSensitivity
		PlayRepSound("AimUp")

		--tweenService:Create(camera,TweenInfo.new(wepStats.aimTime),{FieldOfView = wepStats.aimFovDefault or defaultFOV}):Play()

		if not config.lockFirstPerson then
			player.CameraMode = Enum.CameraMode.LockFirstPerson
		end
	else
		aiming = false
		ToggleADS(false)
		userInputService.MouseDeltaSensitivity = 1
		PlayRepSound("AimDown")
		local aimOutTime
		if wepStats then
			aimOutTime = wepStats.aimTime / 2
		else
			aimOutTime = 0.3
		end
		tweenService:Create(camera,TweenInfo.new(aimOutTime),{FieldOfView = defaultFOV}):Play()
		if not config.lockFirstPerson then
			player.CameraMode = defaultCameraMode
		end
	end
end

local recoilUpdateCD = 0
local fps = 0

-- Update the viewmodel's CFrame
local function UpdateViewmodelPosition(dt:number)
	fps = 1 / dt

	recoilUpdateCD -= dt

	-- Move the viewmodel to the camera's CFrame position and add the gun's offset
	animBase.CFrame = CFrame.new((camera.CFrame * offset).Position)

	-- Check if freelook is on and don't rotate the viewmodel if it is
	if not freeLook then
		animBase.CFrame *= camera.CFrame - camera.CFrame.Position
	else
		animBase.CFrame *= freeLookRotation
	end

	-- Move gunmodel up while prone
	if stance == 2 then
		proneViewmodelOffset = LerpNumber(proneViewmodelOffset,0.2,0.1)
	else
		proneViewmodelOffset = LerpNumber(proneViewmodelOffset,0,0.1)
	end
	animBase.CFrame *= CFrame.new(0,proneViewmodelOffset,0)

	-- Freelook recovery
	local freelookRecovery = 0.2
	freeLookOffset = freeLookOffset:Lerp(CFrame.new(),freelookRecovery * dt * 60)
	animBase.CFrame *= freeLookOffset:Inverse()

	---- Aiming
	--local aimPart = gunModel:FindFirstChild("AimPart"..sightIndex) or gunModel.AimPart
	--aimTarget = aimPart.CFrame:ToObjectSpace(camera.CFrame)
	--if aiming then
	--	aimingOffset = aimingOffset:Lerp(aimTarget,(0.7 / wepStats.aimTime) * 0.3 * dt * 60)
	--else
	--	aimingOffset = aimingOffset:Lerp(CFrame.new(),(0.7 / wepStats.aimTime) * 0.3 * dt * 60)
	--end
	--animBase.CFrame *= aimingOffset

	-- Aiming
	local aimPart = gunModel:FindFirstChild("AimPart"..sightIndex) or gunModel.AimPart
	-- DD_SPH Gunsmith: multiple aimparts on attachments
	if attStats.aimParts then
		if attStats.aimParts["AimPart"..sightIndex] then
			aimPart = gunModel[attStats.aimParts["AimPart"..sightIndex]]:FindFirstChild("AimPart"..sightIndex)
		end
	end
	-- </DD_SPH>
	aimTarget = aimPart.CFrame:ToObjectSpace(camera.CFrame)

	-- DD_SPH gunsmith: Adjusting aim time based on attstats.
	local aimTime = wepStats.aimTime
	if attStats.aimTime then aimTime *= attStats.aimTime end

	if aiming then
		aimingOffset = aimingOffset:Lerp(aimTarget,(0.7 / aimTime) * 0.3 * dt * 60)
	else
		aimingOffset = aimingOffset:Lerp(CFrame.new(),(0.7 / aimTime) * 0.3 * dt * 60)
	end
	animBase.CFrame *= aimingOffset
	-- </DD_SPH>

	-- Check if gun is too close to a wall
	--local rayDistance = (animBase.CFrame.Position - gunModel.Grip.Muzzle.WorldCFrame.Position).Magnitude + 1
	local rayDistance = wepStats.gunLength

	if attStats.gunLength then rayDistance += attStats.gunLength end -- DD_SPH Gunsmith: Adding gun length
	local originCFrame = firstPerson and animBase.CFrame or weaponRig.AnimBase.CFrame
	local newRay = workspace:Raycast(originCFrame.Position,originCFrame.LookVector * rayDistance,rayParams)
	if newRay then
		local distance = rayDistance - (animBase.CFrame.Position - newRay.Position).Magnitude
		if config.pushBackViewmodel and distance > 0 then
			local tempDist = distance
			if blocked then tempDist /= 2 end
			pushbackOffset = LerpNumber(pushbackOffset,tempDist,0.2 * 60 * dt)
		else
			pushbackOffset = LerpNumber(pushbackOffset,0,0.2 * 60 * dt)
		end

		if config.raiseGunAtWall then

			if distance >= wepStats.maxPushback then
				if not blocked then
					ChangeHoldStance(0)
					PlayAnimation(wepStats.holdUpAnim,{looped = true, priority = Enum.AnimationPriority.Action,transSpeed = 0.3})
					blocked = true
					if aiming then ToggleAiming(false) end
				end
			elseif blocked then
				StopAnimation(wepStats.holdUpAnim,0.3)
				blocked = false
				if aimHeld and not aiming and firstPerson then
					ToggleAiming(true)
				end
			end
		end
	else
		if blocked then
			StopAnimation(wepStats.holdUpAnim,0.3)
		end
		blocked = false
		if aimHeld and not aiming and firstPerson and not sprinting then
			ToggleAiming(true)
		end

		pushbackOffset = LerpNumber(pushbackOffset,0,0.2 * 60 * dt)
	end
	animBase.CFrame *= CFrame.new(0,0,pushbackOffset)

	-- Update strafing roll
	local relativeVelocity = humanoidRootPart.CFrame:VectorToObjectSpace(humanoidRootPart.Velocity)
	local targetRollAngle = 0
	if not aiming then targetRollAngle = math.clamp(-relativeVelocity.X, -config.maxStrafeRoll, config.maxStrafeRoll) end
	if config.cameraTilting then targetRollAngle /= 2 end
	rollAngle = LerpNumber(rollAngle, targetRollAngle, 0.07 * dt * 60)
	animBase.CFrame *= CFrame.Angles(0, 0, math.rad(rollAngle))

	local mouseDelta = userInputService:GetMouseDelta()

	-- Update hipfire movement
	local tempHipRotation = hipRotation
	if config.hipfireMove and (not aiming or aiming and config.offCenterAiming) then
		local maxX = config.hipfireMoveX
		local maxY = config.hipfireMoveY
		if aiming then
			maxX /= 4
			maxY /= 4
		end
		local xRotation = math.clamp(tempHipRotation.X - mouseDelta.X * config.hipfireMoveSpeed * dt * 60,-maxX,maxX)
		local yRotation = math.clamp(tempHipRotation.Y - mouseDelta.Y * config.hipfireMoveSpeed * dt * 60,-maxY,maxY)
		tempHipRotation = Vector2.new(xRotation,yRotation)
		hipRotation = tempHipRotation
	else
		hipRotation = hipRotation:Lerp(Vector2.zero,0.3)
	end
	animBase.CFrame *= CFrame.Angles(math.rad(hipRotation.Y),math.rad(hipRotation.X),0)

	-- Update rotational sway
	swaySpring:shove(Vector3.new(-mouseDelta.X / 500, mouseDelta.Y / 200, 0))
	local updatedSway = swaySpring:update(dt)
	animBase.CFrame *= CFrame.new(updatedSway.X, updatedSway.Y, 0)

	-- Update breathing
	local tickTime = tick() * 0.15
	local tempDist = config.breathingDist
	if aiming then tempDist *= config.breathingAimMultiplier end
	animBase.CFrame *= CFrame.new(tempDist * math.sin(tickTime * config.breathingSpeed / 2), tempDist * math.sin(tickTime * config.breathingSpeed), 0)

	-- Update recoil
	local recoilStats = wepStats.recoil
	local gunRecoil = wepStats.gunRecoil

	local updatedRecoil = recoilSpring.Position
	local updatedGunRecoil = gunRecoilSpring:update(dt)
	if recoilUpdateCD <= 0 then
		recoilUpdateCD = 1 / 60
		local currentFPS = 1 / dt
		local dtMult = (currentFPS / 60) - 1
		dtMult = dtMult / 2
		updatedRecoil = recoilSpring:update(0.016 + (0.016 * dtMult))
	end

	animBase.CFrame *= CFrame.Angles(math.rad(updatedGunRecoil.X), math.rad(updatedGunRecoil.Y), 0)
	animBase.CFrame *= CFrame.new(0,0,updatedGunRecoil.Z)
	camera.CFrame *= CFrame.Angles(math.rad(updatedRecoil.X),math.rad(updatedRecoil.Y),math.rad(updatedRecoil.Z))

	-- Viewmodel visibility
	if not viewmodelVisible then
		animBase.CFrame *= storageCFrame
	end
end

local function ChangeDoF(fInt,fDist,fRad,nInt)
	tweenService:Create(depthOfField,TweenInfo.new(0.2),{
		FarIntensity = fInt,
		FocusDistance = fDist,
		InFocusRadius = fRad,
		NearIntensity = nInt
	}):Play()
end

-- Toggle spring speed
local function ToggleSprint(toggle:boolean)
	sprinting = toggle
	character:SetAttribute("Sprinting", toggle)
	if toggle then
		if aiming then ToggleAiming(false) end
		ChangeHoldStance(0)
		userInputService.MouseDeltaSensitivity = 1
		holdingM1 = false
		PlayAnimation(wepStats.sprintAnim,{looped = true, priority = Enum.AnimationPriority.Action, transSpeed = 0.2})

		if depthOfField then
			ChangeDoF(0,6,0,0.3)
		end
	elseif wepStats then
		StopAnimation(wepStats.sprintAnim,0.2)

		if depthOfField then
			ChangeDoF(0,0,0,0)
		end
	end
end

-- Update target walk speed
-- This function is here in case the speed needs to be modified for whatever reason
local function ChangeWalkSpeed(newSpeed)
	targetWalkSpeed = newSpeed
end

local baseCharacterHipHeight = player.Character:WaitForChild("Humanoid").HipHeight -- DD_SPH: Gets player's character's hipheight

local function ChangeStance(change)
	local number = stance + change
	local targetCharacterHeight = 0 -- DD_SPH: TargetCharacterHeight adjusts for rigtype

	-- Correct number if it's too low or too high
	if number < 0 then
		number = 0
	elseif number > 2 then
		number = 2
	end

	local preMove = false
	if moveAnim then
		preMove = moveAnim.IsPlaying
	end

	if number == 0 then -- Walking
		script.Parent.MovementLeaning:SetAttribute("DisableLean", false)
		if moveAnim then moveAnim:Stop(config.stanceChangeTime) end
		moveAnim = nil
		crouchIdleAnim:Stop(config.stanceChangeTime)
		ChangeWalkSpeed(config.walkSpeed)

		if rigType == Enum.HumanoidRigType.R6 then -- DD_SPH: Rig check!
			targetCharacterHeight = 0
		else
			targetCharacterHeight = baseCharacterHipHeight
		end

		tweenService:Create(humanoid,TweenInfo.new(config.stanceChangeTime),{HipHeight = targetCharacterHeight}):Play() -- DD_SPH: Use targetCharacterHeight instead of 0
		PlayCharSound("Uncrouch")
	elseif number == 1 then -- Crouching
		script.Parent.MovementLeaning:SetAttribute("DisableLean", false)
		if moveAnim then moveAnim:Stop(config.stanceChangeTime) end
		moveAnim = crouchMoveAnim
		if moving then moveAnim:Play(config.stanceChangeTime) end
		proneIdleAnim:Stop(config.stanceChangeTime)
		crouchIdleAnim:Play(config.stanceChangeTime)
		ChangeWalkSpeed(config.crouchSpeed)

		if rigType == Enum.HumanoidRigType.R6 then -- DD_SPH: Rig check!
			targetCharacterHeight = 0
		else
			targetCharacterHeight = baseCharacterHipHeight
		end

		tweenService:Create(humanoid,TweenInfo.new(config.stanceChangeTime),{HipHeight = targetCharacterHeight}):Play() -- DD_SPH: Use targetCharacterHeight instead of 0
		if stance == 0 then
			PlayCharSound("Crouch")
		elseif stance == 2 then
			PlayCharSound("Unprone")
		end
	elseif number == 2 then -- Prone
		ChangeLean(0)
		script.Parent.MovementLeaning:SetAttribute("DisableLean", true)
		if moveAnim then moveAnim:Stop(config.stanceChangeTime) end
		moveAnim = proneMoveAnim
		crouchIdleAnim:Stop(config.stanceChangeTime)
		proneIdleAnim:Play(config.stanceChangeTime)
		ChangeWalkSpeed(config.proneSpeed)

		if rigType == Enum.HumanoidRigType.R6 then -- DD_SPH: Rig check!
			targetCharacterHeight = -2
		else
			targetCharacterHeight = baseCharacterHipHeight * 0.5
		end

		tweenService:Create(humanoid,TweenInfo.new(config.stanceChangeTime * 1.5),{HipHeight = targetCharacterHeight}):Play() -- DD_SPH: Use targetCharacterHeight instead of 0
		PlayCharSound("Prone")
	end

	if preMove and moveAnim then moveAnim:Play() end

	stance = number
end

local function HandleInput(actionName, inputState, inputObject)
	local inputBegan = Enum.UserInputState.Begin
	local inputEnded = Enum.UserInputState.End


	if actionName == "SPH_Sprint" then -- Sprint hold
		sprintHeld = inputState == inputBegan
		if sprintHeld and stance < 2 and moving then -- Begin sprinting
			if stance == 1 then ChangeStance(-1) end
			if equipped and moving then ToggleSprint(true) end
			ChangeWalkSpeed(config.sprintSpeed)
			ChangeLean(0)
		elseif stance == 0 then -- End sprinting
			ToggleSprint(false)
			ChangeWalkSpeed(config.walkSpeed)
		end
	elseif inputState == inputBegan then -- Other inputs

		if actionName == "SPH_StanceLower" and inputState == inputBegan and stance < 2 and not humanoid.Sit then -- Lower stance
			if not config.canProne and stance == 1 then return end -- If the player is crouched and unable to prone then return
			ChangeStance(1)
			if sprinting then ToggleSprint(false) end


		elseif actionName == "SPH_StanceRaise" and inputState == inputBegan and stance > 0 then -- Raise stance
			ChangeStance(-1)


		elseif actionName == "SPH_LeanLeft" and inputState == inputBegan and stance < 2 and not sprinting and not humanoid.Sit then -- Lean left
			if lean == -1 then
				ChangeLean(0)
			else
				ChangeLean(-1)
			end


		elseif actionName == "SPH_LeanRight" and inputState == inputBegan and stance < 2 and not sprinting and not humanoid.Sit then -- Lean right
			if lean == 1 then
				ChangeLean(0)
			else
				ChangeLean(1)
			end
		end
	end


	if equipped then -- Gun inputs
		if actionName == "SPH_Trigger" then
			if inputState == inputBegan then -- Holding M1
				cancelReload = true
				if not (sprinting or reloading) then -- Detect mouse click
					holdingM1 = true

					if not IsLoaded() and not (equipped:GetAttribute("FireMode") == fireModes.Manual and equipped:GetAttribute("MagAmmo") > 0) then
						PlayRepSound("Click")
					end
				end
			else -- No longer holding M1
				holdingM1 = false
				canFire = true
				bulletsCurrentlyFired = 0
			end


		elseif actionName == "SPH_DropGun" and inputState == inputBegan then -- Gun drop
			Unequip(equipped)
			playerDropGun:Fire()


			--elseif actionName == "SPH_Reload" and inputState == inputBegan and not reloading and cycled then -- Reload
			--	if wepStats.infiniteAmmo or gunAmmo.ArcadeAmmoPool.Value > 0 then
			--		if (wepStats.openBolt and gunAmmo.MagAmmo.Value < gunAmmo.MagAmmo.MaxValue) then
			--			ReloadAnim()
			--		else
			--			if (wepStats.operationType == 4 and equipped.Chambered.Value)
			--				or (wepStats.operationType == 3 and gunAmmo.MagAmmo.Value + 1 >= gunAmmo.MagAmmo.MaxValue)
			--				or (wepStats.operationType == 2 and gunAmmo.MagAmmo.Value >= gunAmmo.MagAmmo.MaxValue) then
			--				return
			--			end
			--			ReloadAnim()
			--		end
			--	end

		elseif actionName == "SPH_Reload" and inputState == inputBegan and not reloading and cycled then -- Reload
			-- [UBGL START] - UBGL Reload Input Handling
			-- Check if we're in UBGL mode
			if curFireMode == fireModes.UBGL and wepStats.hasUBGL then
				-- UBGL reload logic - reload when we have no grenades loaded
				local ubglAmmoPool = equipped:FindFirstChild("UBGLAmmoPool")
				if ubglAmmo and ubglAmmo.Value == 0 and ubglAmmoPool and ubglAmmoPool.Value > 0 then
					-- UBGL is empty and we have grenades in the pool, reload it
					ReloadAnim()
				end
			else
				-- Primary weapon reload logic
				if wepStats.infiniteAmmo or gunAmmo.ArcadeAmmoPool.Value > 0 then
					if (wepStats.openBolt and gunAmmo.MagAmmo.Value < gunAmmo.MagAmmo.MaxValue) then
						ReloadAnim()
					else
						if (wepStats.operationType == 4 and equipped.Chambered.Value)
							or (wepStats.operationType == 3 and gunAmmo.MagAmmo.Value + 1 >= gunAmmo.MagAmmo.MaxValue)
							or (wepStats.operationType == 2 and gunAmmo.MagAmmo.Value >= gunAmmo.MagAmmo.MaxValue) then
							return
						end
						ReloadAnim()
					end
				end
			end
			-- [UBGL END] - UBGL Reload Input Handling


		elseif actionName == "SPH_HoldAim" then
			if not userInputService.TouchEnabled and not config.toggleAiming then -- Hold aiming
				if inputState == inputBegan and firstPerson and not freeLook and not blocked then
					aimHeld = true
					ToggleSprint(false)
					if stance == 0 then ChangeWalkSpeed(config.walkSpeed) end
					ToggleAiming(true)
				elseif not sprinting and aiming then -- Not aiming
					aimHeld = false
					ToggleAiming(false)
				end
			elseif inputState == inputBegan then -- Mobile and toggle aiming
				if firstPerson and not freeLook and not blocked and not aiming then
					aimHeld = true
					ToggleSprint(false)
					if stance == 0 then ChangeWalkSpeed(config.walkSpeed) end
					ToggleAiming(true)
				else
					aimHeld = false
					ToggleAiming(false)
				end
			end


		elseif actionName == "SPH_Chamber" and inputState == inputBegan and not reloading and cycled then -- Chambering
			ChamberAnim()


		elseif actionName == "SPH_SwitchSights" and inputState == inputBegan and aiming and (gunModel:FindFirstChild("AimPart2") or (attStats.aimParts and attStats.aimParts["AimPart2"])) then -- Switch sights
			local tempIndex = sightIndex
			tempIndex += 1
			if gunModel:FindFirstChild("AimPart"..tempIndex) then
				sightIndex = tempIndex
				PlayRepSound("AimUp")	
				-- DD_SPH Gunsmith: Multiple aimparts
			elseif attStats.aimParts then
				if attStats.aimParts["AimPart"..tempIndex] then
					sightIndex = tempIndex
					PlayRepSound("AimUp")
				else
					sightIndex = 1
					PlayRepSound("AimDown")
				end
				-- </DD_SPH>
			else
				sightIndex = 1
				PlayRepSound("AimDown")
			end
			--if wepStats.ADSEnabled and wepStats.ADSEnabled[sightIndex] then
			if (attStats.ADSEnabled and attStats.ADSEnabled[sightIndex]) or (wepStats.ADSEnabled and wepStats.ADSEnabled[sightIndex]) then -- DD_SPH Gunsmith: ADS enabling
				ToggleADS(true)
			else
				ToggleADS(false)
			end


		elseif actionName == "SPH_Freelook" then -- Freelook
			if inputState == inputBegan then -- Holding
				freeLook = true
				humanoid.AutoRotate = false
				freeLookRotation = camera.CFrame - camera.CFrame.Position
			else -- Stopped holding
				freeLook = false
				freeLookOffset = freeLookRotation:ToObjectSpace(camera.CFrame)
				freeLookOffset = freeLookOffset - freeLookOffset.Position
				humanoid.AutoRotate = true
			end
		elseif actionName == "SPH_HoldUp" and inputState == inputBegan and not reloading then -- Hold stance up
			ChangeHoldStance(1)
		elseif actionName == "SPH_HoldPatrol" and inputState == inputBegan and not reloading then -- Hold stance patrol
			ChangeHoldStance(2)
		elseif actionName == "SPH_HoldDown" and inputState == inputBegan and not reloading then -- Hold stance down
			ChangeHoldStance(3)
		elseif actionName == "SPH_SwitchFireMode" and inputState == inputBegan then -- Switch fire mode
			PlayAnimation(wepStats.switchAnim,{transSpeed = 0.2})
		elseif actionName == "SPH_ToggleLaser" and inputState == inputBegan then--and gunModel.Grip:FindFirstChild("Laser") then
			-- DD_SPH Gunsmith: Laser
			local lazerbeem = gunModel.Grip:FindFirstChild("Laser")
			if attStats.laserOrigin then
				lazerbeem = gunModel[attStats.laserOrigin].Main:FindFirstChild("Laser")
			end
			if lazerbeem then
				laserEnabled = not laserEnabled
				if not firstPerson then laserBeamTP.Enabled = true end
				PlayRepSound("Button")
				playerToggleAttachment:Fire(1,laserEnabled)
				laserDotUI.Dot.ImageColor3 = lazerbeem.Color.Value
			end
			-- </DD_SPH>
		elseif actionName == "SPH_ToggleFlashlight" and inputState == inputBegan then
			local flashlight = gunModel.Grip:FindFirstChild("Flashlight")
			if flashlight then
				local light = flashlight:FindFirstChildWhichIsA("Light")
				flashlightEnabled = not flashlightEnabled
				light.Enabled = flashlightEnabled
				PlayRepSound("Button")
				playerToggleAttachment:Fire(0,light.Enabled)

				if not flashlightEnabled then
					weaponRig.Weapon:FindFirstChildWhichIsA("Model").Grip.Flashlight:FindFirstChildWhichIsA("Light").Enabled = false
				elseif not firstPerson then
					weaponRig.Weapon:FindFirstChildWhichIsA("Model").Grip.Flashlight:FindFirstChildWhichIsA("Light").Enabled = true
				end
			end
			-- DD_SPH Gunsmith
			if attStats.flashlights_client then
				if not flashlight then -- this makes sure that the flashlight toggle doesn't happen twice if you have both factory and gunsmith flashlights
					flashlightEnabled = not flashlightEnabled
				end
				for _, lightAttachment in ipairs(attStats.flashlights_client) do
					local flashlite = lightAttachment.Main:FindFirstChild("Flashlight")
					if flashlite then
						local light = flashlite:FindFirstChildWhichIsA("Light")
						light.Enabled = flashlightEnabled
						PlayRepSound("Button")
						playerToggleAttachment:Fire(0,light.Enabled)

						if not flashlightEnabled then
							weaponRig.Weapon:FindFirstChildWhichIsA("Model")[lightAttachment.Name].Main.Flashlight:FindFirstChildWhichIsA("Light").Enabled = false
						elseif not firstPerson then
							weaponRig.Weapon:FindFirstChildWhichIsA("Model")[lightAttachment.Name].Main.Flashlight:FindFirstChildWhichIsA("Light").Enabled = true
						end
					end
				end
			end
			-- </DD_SPH>
		end
	end
end

InputController.ActionFired = HandleInput
InputController.BindCharacterInputs()

humanoid.Died:Connect(function()
	dead = true
	switchWeapon:Fire()
	equipped = nil
	wepStats = nil
	attStats = {} -- DD_SPH: Gunsmith
	userInputService.MouseIconEnabled = true
	ToggleAiming(false)
	viewmodelVisible = false
	animBase.CFrame = storageCFrame

	InputController.UnbindGunInputs()

	--bodyAnimRequest:Destroy()
	--repReload:Destroy()
	--switchWeapon:Destroy()
	--playerFire:Destroy()
	--playSound:Destroy()
	----bulletHit:Destroy()
	--repChamber:Destroy()
	--moveBolt:Destroy()
	--switchFireMode:Destroy()
	--playCharSound:Destroy()
	--playerDropGun:Destroy()
	--playerToggleAttachment:Destroy()
	--repBoltOpen:Destroy()
	--magGrab:Destroy()
	--playerLean:Destroy()

	if config.useDeathCameraSubject then
		repeat task.wait() until humanoid.Parent ~= character
		camera.CameraSubject = humanoid
	end

	if rig then rig:Destroy() end
end)

function Unequip(tool) -- Unequip a gun (Does not remove it from the player's character, must be global)
	animBase.CFrame = storageCFrame
	
	lastGunModel = gunModel -- DD_SPH Reload Swap Fix: Stops shell-based reloads from continuing on the next gun you equip (e.g. start shell insert on M1891, equip RPG and reload continues on RPG)

	switchWeapon:Fire()
	if tool == equipped then
		equipped = nil
		wepStats = nil
		attStats = {} -- DD_SPH Gunsmith
	end
	userInputService.MouseIconEnabled = true
	ToggleAiming(false)
	aimHeld = false --- DD_SPH ADS Fix: Stops gun from automatically aiming down sights if you aim down sights, unequip and re-equip it
	viewmodelVisible = false

	-- Stop animations
	for _, track in ipairs(vmAnimator:GetPlayingAnimationTracks()) do
		track:Stop()
	end

	for _, track in ipairs(characterAnimator:GetPlayingAnimationTracks()) do
		track:Stop()
	end

	if config.lockFirstPerson then
		player.CameraMode = Enum.CameraMode.Classic
	end

	sights = {}

	freeLook = false
	freeLookOffset = freeLookRotation:ToObjectSpace(camera.CFrame)
	freeLookOffset = freeLookOffset - freeLookOffset.Position
	humanoid.AutoRotate = true

	if depthOfField then ChangeDoF(0,0,0,0) end

	holdStance = 0
	holdAnim = nil

	laserEnabled = false
	flashlightEnabled = false
	bipodEnabled = false -- DD_SPH Bipod
	laserDotUI.Enabled = false

	laserBeamFP.Enabled = false
	laserBeamTP.Enabled = false

	InputController.UnbindGunInputs()
end

local function GetRotationBetween(u, v, axis)
	local dot, uxv = u:Dot(v), u:Cross(v)
	if (dot < -0.99999) then return CFrame.fromAxisAngle(axis, math.pi) end
	return CFrame.new(0, 0, 0, uxv.x, uxv.y, uxv.z, 1 + dot)
end

local function SetAttachment(weapon, attachmentSlot, weaponAttachment, parentPart) -- DD_SPH Gunsmith: Setting attachment models for the viewmodel weapon
	local newAttachment = gunsmith.placeAttachment(weapon, attachmentSlot, weaponAttachment, parentPart) -- no difference between client/server

	-- client-specific stuff begins
	if not assets.Attachments:FindFirstChild(weaponAttachment) then warn(weaponAttachment.."Not found in SPH_Assets.Attachments!") return end
	local newAttStats = require(assets.Attachments[weaponAttachment].AttStats)
	-- enable ADS
	if newAttStats.ADSEnabled then
		if attStats.ADSEnabled then
			warn("Multiple attachments enabling ADS Mesh")
		else
			attStats.ADSEnabled = newAttStats.ADSEnabled
		end
	end

	-- Add sight parts and aimparts
	for _, part in ipairs(newAttachment:GetChildren()) do
		if part.Name == "SightReticle" then
			table.insert(sights,part)
		end

		if string.find(part.Name, "AimPart") then -- check aimparts
			if not attStats.aimParts then
				attStats.aimParts = {}
			end
			if not attStats.aimParts[part.Name] then
				attStats.aimParts[part.Name] = newAttachment.Name
			else
				-- count up until you find a number that's not taken, rename this part accordingly
				local newSightIndex = 1
				for i, ap in attStats.aimParts do
					newSightIndex += 1
				end
				part.Name = "AimPart"..newSightIndex
				attStats.aimParts[part.Name] = newAttachment.Name
			end
			if weapon:FindFirstChild(part.Name) then -- there is a same-name aimpart on this weapon
				weapon.Grip["Grip_"..part.Name]:Destroy()
				weapon[part.Name].CFrame = part.CFrame
				weldMod.Weld(weapon[part.Name], weapon.Grip)
			end
		end
	end

	if newAttachment.Main:FindFirstChild("Flashlight") then
		if not attStats.flashlights_client then
			attStats.flashlights_client = {}
		end
		table.insert(attStats.flashlights_client, newAttachment)
	end

	weldMod.WeldModel(newAttachment, parentPart[attachmentSlot], false)
end		-- </DD_SPH>

-- DD_SPH: Recursive attachments
local function setRecursiveAttachments(weapon, attachmentSlot, weaponAttachment, parentPart)
	if not weaponAttachment or weaponAttachment == "" then return end
	if typeof(weaponAttachment) == "string" then
		if not parentPart:FindFirstChild(attachmentSlot) then warn("No slot found for "..weaponAttachment) return end

		SetAttachment(weapon, attachmentSlot, weaponAttachment, parentPart)
	elseif typeof(weaponAttachment) == "table" then
		local subAttachment = weaponAttachment[1]
		local subAttachmentNodes = weaponAttachment[2]
		SetAttachment(weapon, attachmentSlot, subAttachment, parentPart)
		for item, name in pairs(subAttachmentNodes) do
			setRecursiveAttachments(weapon, item, name, weapon[subAttachment])
		end
	end
end
-- </DD_SPH>

-- Equip function
character.ChildAdded:Connect(function(newChild)
	if newChild:FindFirstChild("SPH_Weapon") and not assets.WeaponModels:FindFirstChild(newChild.Name) then
		warn(warnPrefix.."No gun model could be found for '"..newChild.Name.."'")
		return
	end

	if newChild:FindFirstChild("SPH_Weapon") and not dead and (not humanoid.Sit or humanoid.Sit and not vehicleSeated) then
		-- Reset variables
		reloading = false
		userInputService.MouseIconEnabled = false
		hipRotation = Vector2.zero
		equipping = true
		blocked = false
		laserEnabled = false
		cycled = true
		chambering = false

		switchWeapon:Fire(newChild)

		-- Setup new gun
		equipped = newChild
		wepStats = require(equipped.SPH_Weapon.WeaponStats)
		recoilSpring.Damping = wepStats.recoil.damping
		recoilSpring.Speed = wepStats.recoil.speed
		gunRecoilSpring.Damping = wepStats.gunRecoil.damping
		gunRecoilSpring.Speed = wepStats.gunRecoil.speed
		offset = wepStats.viewmodelOffset
		aimFOVTarget = wepStats.aimFovDefault or defaultFOV
		freeLookOffset = CFrame.new()
		aimSensitivity = wepStats.aimSpeed

		if not wepStats.operationType then wepStats.operationType = 1 end

		if type(wepStats.operationType) == "string" then
			wepStats.operationType = 1
		end
		if not wepStats.magType then
			wepStats.magType = 1
		end

		-- Destroy old gun model
		local oldGun = rig.Weapon:FindFirstChildWhichIsA("Model")
		if oldGun then oldGun:Destroy() end

		-- New gun model
		local gun = assets.WeaponModels:FindFirstChild(newChild.Name)
		if not gun then warn(warnPrefix.."Could not find a gun model with the name: '".. newChild.Name.. "'!") return end
		gun = gun:Clone()

		weldMod.WeldModel(gun,gun.Grip,false)

		-- DD_SPH: Place Attachments
		if wepStats.Attachments then -- is there a table of attachments
			attStats = gunsmith.getAttStats(wepStats.Attachments) -- calculate based on attachment set
			for slot, item in wepStats.Attachments do
				if typeof(item) == "string" then
					if not gun:FindFirstChild(slot) then warn("No slot found for "..slot) continue end
					SetAttachment(gun, slot, item, gun)
				elseif typeof(item) == "table" then
					setRecursiveAttachments(gun, slot, item, gun)
				else 
					warn("Node type"..(slot ~= nil and typeof(slot) or "nil").."not recognized")
				end
			end
		end

		-- DD_SPH Gunsmith: Adjust recoil springs based on attachments
		if attStats.recoil then
			recoilSpring.Damping *= attStats.recoil.damping
			recoilSpring.Speed *= attStats.recoil.speed
		end

		if attStats.gunRecoil then
			gunRecoilSpring.Damping *= attStats.gunRecoil.damping
			gunRecoilSpring.Speed *= attStats.gunRecoil.speed
		end

		--
		if attStats.aimFovDefault then
			aimFOVTarget = attStats.aimFovDefault
		end
		-- </DD_SPH>

		for _, partName in ipairs(wepStats.rigParts) do
			if gun:FindFirstChild(partName) then
				gun.Grip["Grip_"..partName]:Destroy()
				local newMotor = weldMod.M6D(gun.Grip,gun[partName])
				newMotor.Name = partName
				newMotor.Parent = gun.Grip
			end
		end

		-- Add sight parts
		for _, part in ipairs(gun:GetDescendants()) do -- DD_SPH Gunsmith: Replaced with getdescendants
			if part.Name == "SightReticle" then
				table.insert(sights,part)
			end
		end

		gun.Parent = rig.Weapon
		gunModel = gun
		weldMod.BlankM6D(rig.AnimBase,gun.Grip)

		if firstPerson then
			RefreshViewmodel()
		end

		InputController.BindGunInputs(firstPerson)

		ToggleSprint(sprintHeld)
		EquipAnim()
		IdleAnim()

		gunAmmo = newChild:WaitForChild("Ammo")

		-- [UBGL START] - UBGL Ammo Initialization
		-- Initialize UBGL ammo if this weapon has UBGL
		if wepStats.hasUBGL then
			-- Get or create UBGL ammo values
			ubglAmmo = newChild:FindFirstChild("UBGLAmmo")
			local ubglAmmoPool = newChild:FindFirstChild("UBGLAmmoPool")

			-- These should already exist from server, but create if missing
			if not ubglAmmo then
				ubglAmmo = Instance.new("IntValue")
				ubglAmmo.Name = "UBGLAmmo"
				ubglAmmo.Parent = newChild

				-- Initialize values only if creating new
				local totalStartAmmo = wepStats.ubgl.startAmmoPool or 6
				if totalStartAmmo > 0 and (not ubglAmmoPool or ubglAmmoPool.Value > 0) then
					ubglAmmo.Value = 1
				else
					ubglAmmo.Value = 0
				end
			end

			if not ubglAmmoPool then
				ubglAmmoPool = Instance.new("DoubleConstrainedValue")
				ubglAmmoPool.Name = "UBGLAmmoPool"
				ubglAmmoPool.MaxValue = wepStats.ubgl.maxAmmoPool or 12
				ubglAmmoPool.Parent = newChild

				-- Initialize pool value only if creating new
				local totalStartAmmo = wepStats.ubgl.startAmmoPool or 6
				if totalStartAmmo > 0 then
					ubglAmmoPool.Value = totalStartAmmo - (ubglAmmo.Value or 0)
				else
					ubglAmmoPool.Value = 0
				end
			end

			-- Preload UBGL animations if they exist
			if wepStats.ubgl.reloadAnim then
				local animSpeed = wepStats.reloadSpeedModifier		-- DD_SPH gunsmith: adjusting reload speed
				if attStats.reloadSpeedModifier then animSpeed *= attStats.reloadSpeedModifier end
				PlayAnimation(wepStats.ubgl.reloadAnim,{speed = animSpeed,priority = Enum.AnimationPriority.Action2,transSpeed = 0.17},"Reload",true) -- DD_SPH gunsmith: Originally used wepstats reloadspeedmodifier
			end
		else
			-- Clear UBGL reference if weapon doesn't have UBGL
			ubglAmmo = nil
		end
		-- [UBGL END] - UBGL Ammo Initialization

		if not equipped.BoltReady.Value then
			MoveBolt(wepStats.boltDist,true)
		end

		if config.lockFirstPerson then
			player.CameraMode = Enum.CameraMode.LockFirstPerson
		end

		curFireMode = equipped.FireMode.Value

		if gunModel.Grip:FindFirstChild("Laser") then
			laserBeamFP.Attachment0 = gunModel.Grip.Laser
		end

		-- DD_SPH Gunsmith: Laser
		if attStats.laserOrigin and gunModel[attStats.laserOrigin].Main:FindFirstChild("Laser") then
			laserBeamFP.Attachment0 = gunModel[attStats.laserOrigin].Main.Laser		
		end

		-- DD_SPH gunsmith: adjusting reload speed
		local animSpeed = wepStats.reloadSpeedModifier
		if attStats.reloadSpeedModifier then animSpeed *= attStats.reloadSpeedModifier end


		-- Preload animations
		if wepStats.magType == 1 then
			PlayAnimation(wepStats.reloadAnim,{speed = animSpeed,priority = Enum.AnimationPriority.Action2,transSpeed = 0.17},"Reload",true) -- DD_SPH gunsmith: Originally used wepstats reloadspeedmodifier
		else
			PlayAnimation(wepStats.reloadAnim,{speed = animSpeed,priority = Enum.AnimationPriority.Action2,transSpeed = 0, looped = gunAmmo.MagAmmo.MaxValue > 1},"Reload",true) -- DD_SPH gunsmith: Originally used wepstats reloadspeedmodifier
			if wepStats.magType == 3 then
				PlayAnimation(wepStats.clipReloadAnim,{speed = animSpeed,priority = Enum.AnimationPriority.Action2,transSpeed = 0.17, looped = false},"Reload",true) -- DD_SPH gunsmith: Originally used wepstats reloadspeedmodifier
			end
		end

		local newEquipAnim: AnimationTrack = PlayAnimation(wepStats.equipAnim,{priority = Enum.AnimationPriority.Action2},"Equip", true)
		newEquipAnim.Stopped:Connect(function()
			equipping = false
		end)

		PlayAnimation(wepStats.boltChamber,{priority = Enum.AnimationPriority.Action2, transSpeed = 0.05, looped = false},"Chamber", true)

		if wepStats.operationType == 2 or wepStats.operationType == 3 then
			PlayAnimation(wepStats.boltOpen,{priority = Enum.AnimationPriority.Action2, transSpeed = 0, looped = false},"BoltOpen", true)
			PlayAnimation(wepStats.boltClose,{priority = Enum.AnimationPriority.Action2, looped = false},"BoltClose", true)
		end
		
		wait(1)
		lastGunModel = newChild -- DD_SPH: Check against reload swapping
	end
end)

-- Unequip function
character.ChildRemoved:Connect(function(oldChild)
	if equipped and oldChild:FindFirstChild("SPH_Weapon") and assets.WeaponModels:FindFirstChild(oldChild.Name) then
		Unequip(oldChild)
	end
end)

runService.Heartbeat:Connect(function(dt:number)
	-- Mouse click code
	if equipped and not dead and holdingM1 and cycled and not sprinting and not reloading then

		-- Can the player fire this gun?
		--if canFire and not blocked and holdStance == 0 and IsLoaded() and curFireMode > 0 and (config.fireWithFreelook or (not config.fireWithFreelook and not freeLook)) and not equipping then
		--	if not firstPerson and not config.thirdPersonFiring then return end
		--	-- Fire gun

		--	if wepStats.fireAnim then PlayAnimation(wepStats.fireAnim,{priority = Enum.AnimationPriority.Action2, looped = false}) end

		--	bulletsCurrentlyFired += 1
		--	ejected = false

		--	if curFireMode == fireModes.Semi or curFireMode == fireModes.Manual or (curFireMode == fireModes.Burst and bulletsCurrentlyFired >= wepStats.burstNumber) then
		--		canFire = false
		--		holdingM1 = false
		--	end
		--	cycled = false
		--	local curModel = weaponRig.Weapon:FindFirstChildWhichIsA("Model")
		--	curModel = gunModel
		--	local recoilStats = wepStats.recoil
		--	local vertRecoil = recoilStats.vertical
		--	local horzRecoil = recoilStats.horizontal
		--	if aiming then
		--		vertRecoil /= recoilStats.aimReduction
		--		horzRecoil /= recoilStats.aimReduction
		--	end
		--	if stance == 2 then
		--		vertRecoil /= 2
		--		horzRecoil /= 2
		--	end
		--	recoilSpring:shove(Vector3.new(vertRecoil, math.random(-horzRecoil,horzRecoil),recoilStats.camShake))

		--	recoilStats = wepStats.gunRecoil
		--	vertRecoil = recoilStats.vertical
		--	horzRecoil = recoilStats.horizontal
		--	if stance == 2 then
		--		vertRecoil /= 1.5
		--		horzRecoil /= 1.5
		--	end
		--	gunRecoilSpring:shove(Vector3.new(vertRecoil, math.random(-horzRecoil,horzRecoil),recoilStats.punchMultiplier))

		--	-- Shell ejection
		--	if curFireMode ~= fireModes.Manual then
		--		EjectShell()
		--	end

		--	-- Bullet visibility
		--	local bulletHandlerPart = wepStats.bulletHolder and gunModel:FindFirstChild(wepStats.bulletHolder)
		--	if bulletHandlerPart then
		--		local bulletNumber = gunAmmo.MagAmmo.MaxValue - (gunAmmo.MagAmmo.Value - 1)
		--		local tempBulletPart = bulletHandlerPart:FindFirstChild("Bullet"..bulletNumber)
		--		if tempBulletPart then
		--			tempBulletPart.Transparency = 1
		--		end
		--	end

		--	local tempGunModel = gunModel
		--	if not firstPerson then tempGunModel = weaponRig.Weapon:FindFirstChildWhichIsA("Model") end
		--	bulletHandler.FireFX(player,tempGunModel,"Muzzle",wepStats.muzzleChance)

		--	-- Move bolt
		--	--if gunModel:FindFirstChild("Bolt") then
		--	MoveBolt(wepStats.boltDist)
		--	--end

		--	-- Fire bullet
		--	local shotCount = (wepStats.shotgun and wepStats.shotgunPellets) or 1
		--	repeat
		--		shotCount -= 1
		--		local bulletOrigin, bulletDirection
		--		local tempSpread = wepStats.spread * 100
		--		local spreadCFrame = CFrame.Angles(math.rad(math.random(-tempSpread, tempSpread) / 100), math.rad(math.random(-tempSpread, tempSpread) / 100), 0)
		--		if firstPerson then
		--			bulletOrigin = curModel.Grip.Muzzle.WorldCFrame.Position
		--			bulletDirection = (curModel.Grip.Muzzle.WorldCFrame * spreadCFrame).LookVector
		--		else
		--			local muzzle = weaponRig.Weapon:FindFirstChildWhichIsA("Model").Grip.Muzzle
		--			bulletOrigin = muzzle.WorldCFrame.Position
		--			bulletDirection = (muzzle.WorldCFrame * spreadCFrame).LookVector
		--		end

		--		local bulletVelocity = (bulletDirection * wepStats.muzzleVelocity * 3.5) -- 1 Meter = ~3.5 Studs (According to the dev forum)

		--		local tracerColor = nil
		--		--print(gunAmmo.MagAmmo.Value % wepStats.tracerTiming)
		--		if wepStats.tracers and gunAmmo.MagAmmo.Value % wepStats.tracerTiming == 0 then
		--			tracerColor = wepStats.tracerColor
		--		end

		--		bulletHandler.FireBullet(weaponRig,bulletOrigin,bulletDirection,bulletVelocity,equipped,player,tracerColor)
		--	until shotCount <= 0

		--	playerFire:Fire(curModel.Grip.Muzzle.WorldCFrame)

		--	local cycleTime = wepStats.fireRate
		--	if curFireMode == fireModes.Burst and wepStats.burstFireRate then
		--		cycleTime = wepStats.burstFireRate
		--	end

		--	if gunModel and wepStats.projectile ~= "Bullet" and gunModel:FindFirstChild(wepStats.projectile) then
		--		local projectile = gunModel:FindFirstChild(wepStats.projectile)
		--		projectile.LocalTransparencyModifier = 1
		--		for _, child in ipairs(projectile:GetDescendants()) do
		--			if child:IsA("BasePart") then
		--				child.LocalTransparencyModifier = 1
		--			end
		--		end
		--	end

		--	task.wait(60 / cycleTime)

		--	if not equipped then return end

		--	if wepStats.autoChamber and curFireMode == fireModes.Manual and not reloading then
		--		ChamberAnim()
		--	end

		--	cycled = true
		if canFire and not blocked and holdStance == 0 and IsLoaded() and curFireMode > 0 and (config.fireWithFreelook or (not config.fireWithFreelook and not freeLook)) and not equipping then -- UBGL
			if not firstPerson and not config.thirdPersonFiring then return end
			-- [UBGL START] - UBGL/Primary Weapon Firing System
			-- Fire gun

			-- Get current weapon stats based on fire mode
			local currentStats = GetCurrentWepStats()

			if currentStats.fireAnim then PlayAnimation(currentStats.fireAnim,{priority = Enum.AnimationPriority.Action2, looped = false}) end

			bulletsCurrentlyFired += 1
			ejected = false

			-- UBGL is always single shot, so treat it like semi-auto
			if curFireMode == fireModes.Semi or curFireMode == fireModes.Manual or curFireMode == fireModes.UBGL or (curFireMode == fireModes.Burst and bulletsCurrentlyFired >= currentStats.burstNumber) then
				canFire = false
				holdingM1 = false
			end
			cycled = false
			local curModel = weaponRig.Weapon:FindFirstChildWhichIsA("Model")
			curModel = gunModel
			local recoilStats = currentStats.recoil
			local vertRecoil = recoilStats.vertical
			local horzRecoil = recoilStats.horizontal

			-- DD_SPH Gunsmith: Adjusting recoil
			if attStats.recoil then
				vertRecoil *= attStats.recoil.vertical
				horzRecoil *= attStats.recoil.horizontal
				recoilStats.camShake *= attStats.recoil.camShake
				recoilStats.aimReduction *= attStats.recoil.aimReduction
			end
			-- </DD_SPH>

			-- DD_SPH Bipod: Reducing recoil
			if bipodEnabled then
				vertRecoil /= 4
				horzRecoil /= 4
			end

			if aiming then
				vertRecoil /= recoilStats.aimReduction
				horzRecoil /= recoilStats.aimReduction
			end
			if stance == 2 then
				vertRecoil /= 2
				horzRecoil /= 2
			end

			recoilSpring:shove(Vector3.new(vertRecoil, math.random(-horzRecoil,horzRecoil),recoilStats.camShake))

			recoilStats = currentStats.gunRecoil
			vertRecoil = recoilStats.vertical
			horzRecoil = recoilStats.horizontal

			if attStats.gunRecoil then -- DD_SPH Gunsmith: Adjusting gun recoil
				vertRecoil *= attStats.gunRecoil.vertical
				horzRecoil *= attStats.gunRecoil.horizontal
				recoilStats.punchMultiplier *= attStats.gunRecoil.punchMultiplier
			end -- </DD_SPH>

			if stance == 2 then
				vertRecoil /= 1.5
				horzRecoil /= 1.5
			end

			-- DD_SPH Bipod: Reducing gun recoil
			if bipodEnabled then
				vertRecoil /= 3
				horzRecoil /= 3
			end

			gunRecoilSpring:shove(Vector3.new(vertRecoil, math.random(-horzRecoil,horzRecoil),recoilStats.punchMultiplier))

			-- Shell ejection (UBGL doesn't eject shells)
			if curFireMode ~= fireModes.Manual and curFireMode ~= fireModes.UBGL then
				EjectShell()
			end

			-- Bullet visibility (only for primary weapon)
			if curFireMode ~= fireModes.UBGL then
				local bulletHandlerPart = wepStats.bulletHolder and gunModel:FindFirstChild(wepStats.bulletHolder)
				if bulletHandlerPart then
					local bulletNumber = gunAmmo.MagAmmo.MaxValue - (gunAmmo.MagAmmo.Value - 1)
					local tempBulletPart = bulletHandlerPart:FindFirstChild("Bullet"..bulletNumber)
					if tempBulletPart then
						tempBulletPart.Transparency = 1
					end
				end
			end

			local tempGunModel = gunModel
			if not firstPerson then tempGunModel = weaponRig.Weapon:FindFirstChildWhichIsA("Model") end

			-- Use appropriate muzzle point for effects
			local muzzleName = "Muzzle"
			if curFireMode == fireModes.UBGL then
				muzzleName = "UBGLMuzzle"
			end
			local muCh = attStats.muzzleChance or wepStats.muzzleChance -- DD_SPH Gunsmith: Adjusting muzzle chance
			if attStats.newMuzzleDevice then
				tempGunModel = tempGunModel[attStats.newMuzzleDevice]
			end
			bulletHandler.FireFX(player,tempGunModel,muzzleName,muCh,curFireMode == fireModes.UBGL)

			-- [UBGL START] - UBGL Fire Sound
			-- Play fire sound (UBGL-specific or fallback)
			PlayRepSound("Fire")
			-- [UBGL END] - UBGL Fire Sound

			-- Move bolt (only for primary weapon)
			if curFireMode ~= fireModes.UBGL then
				MoveBolt(currentStats.boltDist)
			end

			-- Fire bullet/grenade
			local shotCount = (currentStats.shotgun and currentStats.shotgunPellets) or 1
			repeat
				shotCount -= 1
				local bulletOrigin, bulletDirection
				local tempSpread = currentStats.spread * 100
				local spreadCFrame = CFrame.Angles(math.rad(math.random(-tempSpread, tempSpread) / 100), math.rad(math.random(-tempSpread, tempSpread) / 100), 0)

				-- Get appropriate muzzle point
				local muzzlePoint
				if firstPerson then
					muzzlePoint = GetMuzzlePoint(curModel)
					bulletOrigin = muzzlePoint.WorldCFrame.Position
					bulletDirection = (muzzlePoint.WorldCFrame * spreadCFrame).LookVector
				else
					local tempModel = weaponRig.Weapon:FindFirstChildWhichIsA("Model")
					muzzlePoint = GetMuzzlePoint(tempModel)
					bulletOrigin = muzzlePoint.WorldCFrame.Position
					bulletDirection = (muzzlePoint.WorldCFrame * spreadCFrame).LookVector
				end

				--local bulletVelocity = (bulletDirection * currentStats.muzzleVelocity * 3.5) -- 1 Meter = ~3.5 Studs (According to the dev forum)

				-- DD_SPH Gunsmith: Muzzle Velocity alteration based on attStats
				local muVe = currentStats.muzzleVelocity
				if attStats.muzzleVelocityReplace then -- Replace the muzzle velocity with a new one (swapping calibers)
					muVe = attStats.muzzleVelocityReplace
				end
				if attStats.muzzleVelocity then -- Increase or decrease muzzle velocity by a certain percentage (barrel length, improved rifling etc.)
					muVe *= attStats.muzzleVelocity
				end
				local bulletVelocity = (bulletDirection * muVe * 3.5) -- 1 Meter = ~3.5 Studs (According to the dev forum)
				-- </DD_SPH Gunsmith

				local tracerColor = nil
				-- Only use tracers for primary weapon
				-- DD_SPH Gunsmith: Adjusting tracer timing with gunsmith
				local TrTi = currentStats.tracerTiming
				if TrTi then
					if attStats.tracerTiming then
						TrTi = currentStats.tracerTiming
					end
				end
				if curFireMode ~= fireModes.UBGL and currentStats.tracers and gunAmmo.MagAmmo.Value % TrTi == 0 then
					tracerColor = attStats.tracerColor or currentStats.tracerColor-- DD_SPH Gunsmith: Tracer alteration based on rounds
				end

				-- Create a modified tool for UBGL mode that includes fire mode info
				local bulletData = equipped
				if curFireMode == fireModes.UBGL then
					-- Add fire mode information for bullet physics
					bulletData = {
						Tool = equipped,
						fireMode = curFireMode,
						SPH_Weapon = equipped.SPH_Weapon
					}
				end

				bulletHandler.FireBullet(weaponRig,bulletOrigin,bulletDirection,bulletVelocity,bulletData,player,tracerColor)
			until shotCount <= 0

			-- Fire the appropriate muzzle point for networking
			local firePoint
			if firstPerson then
				firePoint = GetMuzzlePoint(curModel)
			else
				firePoint = GetMuzzlePoint(weaponRig.Weapon:FindFirstChildWhichIsA("Model"))
			end
			playerFire:Fire(firePoint.WorldCFrame)

			local cycleTime = currentStats.fireRate
			if curFireMode == fireModes.Burst and currentStats.burstFireRate then
				cycleTime = currentStats.burstFireRate
			end

			if attStats.fireRate then cycleTime *= attStats.fireRate end -- DD_SPH Gunsmith: Adjusting fire rate

			-- Handle projectile visibility
			if gunModel and currentStats.projectile ~= "Bullet" and gunModel:FindFirstChild(currentStats.projectile) then
				local projectile = gunModel:FindFirstChild(currentStats.projectile)
				projectile.LocalTransparencyModifier = 1
				for _, child in ipairs(projectile:GetDescendants()) do
					if child:IsA("BasePart") then
						child.LocalTransparencyModifier = 1
					end
				end
			end

			task.wait(60 / cycleTime)
			-- [UBGL END] - UBGL/Primary Weapon Firing System

			if not equipped then return end

			if currentStats.autoChamber and curFireMode == fireModes.Manual and not reloading then
				ChamberAnim()
			end

			cycled = true
			-- </UBGL>
		else
			-- Chamber gun
			if not IsLoaded() then
				if curFireMode == fireModes.Manual and gunAmmo.MagAmmo.Value > 0 and not reloading and not chambering then -- Click chamber
					ChamberAnim()
					holdingM1 = false
				end
			elseif wepStats.emptyCloseBolt then
				repChamber:Fire()
				MoveBolt(CFrame.new())
			end
		end
	end
end)

runService.RenderStepped:Connect(function(dt:number)
	if math.ceil(1 / dt) < 5 then -- Skip the render stepped function if FPS is lower than 5 to avoid stuttering issues
		print(warnPrefix.."RenderStepped skipped due to low framerate.")
		return
	end

	headRotationEventCooldown -= dt

	-- Limit camera rotation
	if (humanoid.Sit and not vehicleSeated and firstPerson or freeLook) and config.cameraLimitInSeats then
		local cameraCFrame = humanoidRootPart.CFrame:ToObjectSpace(camera.CFrame)
		local x, y, z = cameraCFrame:ToOrientation()
		local a = camera.CFrame.Position.X
		local b = camera.CFrame.Position.Y
		local c = camera.CFrame.Position.Z

		local xlimit = math.rad(math.clamp(math.deg(x),-60,60))
		local ylimit = math.rad(math.clamp(math.deg(y),-60,60))
		local zlimit = math.rad(math.clamp(math.deg(z),-60,60))
		local limitedCFrame = humanoidRootPart.CFrame:ToWorldSpace(CFrame.new(a,b,c) * CFrame.fromOrientation(xlimit,ylimit,zlimit))
		camera.CFrame = CFrame.new(camera.CFrame.Position) * (limitedCFrame - limitedCFrame.Position)
	end

	if not dead and character:FindFirstChild("Head") then		
		if not dead then
			local torsoDirection
			if humanoid.RigType == Enum.HumanoidRigType.R6 then
				torsoDirection = character.Torso.CFrame.LookVector
			else
				torsoDirection = character.UpperTorso.CFrame.LookVector
			end

			local lookDirection = camera.CFrame
			if (not config.headRotation or sprinting) and not firstPerson then
				lookDirection = humanoidRootPart.CFrame
			end

			local cameraDirection = humanoidRootPart.CFrame:ToObjectSpace(lookDirection).LookVector
			--local rotationCFrame = CFrame.Angles(0, math.asin(cameraDirection.X)/1.15, 0) * CFrame.Angles(-math.asin(lookDirection.LookVector.Y) + math.asin(torsoDirection.Y), 0, 0)
			--local neckCFrame = CFrame.new(0, -.5, 0) * rotationCFrame * CFrame.Angles(-math.rad(90), 0, math.rad(180))
			local rotationCFrame = CFrame.Angles(0, math.asin(cameraDirection.X)/1.15, 0) * CFrame.Angles(-math.asin(math.clamp(lookDirection.LookVector.Y,-.8,.15)) + math.asin(math.clamp(torsoDirection.Y, -.6,.6)), 0, 0) -- DD_SPH: clamped the Y direction so you can't roll your head into your body like a turtle.. as much.
			local neckCFrame -- DD_SPH: Reworked neck rotation to check by rig
			if humanoid.RigType == Enum.HumanoidRigType.R6 then
				neckCFrame = CFrame.new(0, -.5, 0) * rotationCFrame * CFrame.Angles(-math.rad(90), 0, math.rad(180))
			else
				neckCFrame = CFrame.new(0, -.5, 0) * rotationCFrame * CFrame.Angles(math.rad(0), math.rad(0), math.rad(0))
			end -- </DD_SPH>
			neckJoint.C1 = neckJoint.C1:Lerp(neckCFrame,1 - math.exp(-config.headRotationSpeed * dt))
			--neckJoint.C1 = neckCFrame

			if headRotationEventCooldown <= 0 and not dead and not config.disableHeadRotation then
				headRotationEventCooldown = config.headRotationEventRate
				bodyAnimRequest:Fire(neckJoint.C1)
			end
		end

		-- Check if player is in first person
		if not firstPerson and character.Head.LocalTransparencyModifier >= fpThreshold then
			firstPerson = true
			if equipped then
				InputController.BindAiming()
				if flashlightEnabled then
					if gunModel.Grip:FindFirstChild("Flashlight") then
						gunModel.Grip.Flashlight:FindFirstChildWhichIsA("Light").Enabled = true
						weaponRig.Weapon:FindFirstChildWhichIsA("Model").Grip.Flashlight:FindFirstChildWhichIsA("Light").Enabled = false
					end
					-- DD_SPH Gunsmith
					if attStats.flashlights_client then
						for _, lightAttachment in ipairs(attStats.flashlights_client) do
							lightAttachment.Main.Flashlight:FindFirstChildWhichIsA("Light").Enabled = true
							weaponRig.Weapon:FindFirstChildWhichIsA("Model")[lightAttachment.Name].Main.Flashlight:FindFirstChildWhichIsA("Light").Enabled = false
						end
					end
					-- </DD_SPH>
				end
				if laserEnabled then
					laserBeamTP.Enabled = false
					laserBeamFP.Enabled = true
				end
			end
		elseif firstPerson and character.Head.LocalTransparencyModifier <= fpThreshold then
			firstPerson = false
			InputController.UnbindAiming()
			if equipped then
				if laserEnabled then
					laserBeamTP.Enabled = true
					laserBeamFP.Enabled = false
					if not laserBeamTP.Attachment0 then
						laserBeamTP.Attachment0 = GetThirdPersonGunModel().Grip.Laser
					end
					-- DD_SPH Gunsmith: Laser
					if attStats.laserOrigin and gunModel[attStats.laserOrigin].Main:FindFirstChild("Laser") then
						laserBeamTP.Attachment0 = GetThirdPersonGunModel()[attStats.laserOrigin].Main.Laser		
					end
				end
				if gunModel.Grip:FindFirstChild("Flashlight") then
					gunModel.Grip.Flashlight:FindFirstChildWhichIsA("Light").Enabled = false
					if weaponRig.Weapon:FindFirstChildWhichIsA("Model") and flashlightEnabled then
						weaponRig.Weapon:FindFirstChildWhichIsA("Model").Grip.Flashlight:FindFirstChildWhichIsA("Light").Enabled = true
					end
				end
				-- DD_SPH Gunsmith
				if attStats.flashlights_client then
					for _, lightAttachment in ipairs(attStats.flashlights_client) do
						lightAttachment.Main.Flashlight:FindFirstChildWhichIsA("Light").Enabled = false
						if weaponRig.Weapon:FindFirstChildWhichIsA("Model") and flashlightEnabled then
							weaponRig.Weapon:FindFirstChildWhichIsA("Model")[lightAttachment].Main.Flashlight:FindFirstChildWhichIsA("Light").Enabled = true
						end
					end
				end
				-- </DD_SPH>
			end
			ResetHead()
			cameraOffsetTarget = Vector3.zero
		end

		-- Check if player is moving
		if moveAnim then moveAnim:AdjustSpeed(humanoid.WalkSpeed / 6) end
		if humanoid.MoveDirection.Magnitude > 0 and not moving then
			moving = true
			if moveAnim then moveAnim:Play(config.stanceChangeTime) end
		elseif humanoid.MoveDirection.Magnitude <= 0 then
			moving = false
			if sprinting then
				ToggleSprint(false)
				ChangeWalkSpeed(config.walkSpeed)
			end
			if moveAnim then moveAnim:Stop(config.stanceChangeTime) end
		end

		-- First person body offset

		local xOffset
		local yOffset
		local zOffset


		if rigType == Enum.HumanoidRigType.R6 then -- DD_SPH: Added rig-check to correct positioning

			if config.firstPersonBody and firstPerson then
				local xHead = character.HumanoidRootPart.CFrame:ToObjectSpace(camera.CFrame):ToEulerAngles()
				local rotationOffset = -1.2 + (xHead + 1.4) / 2.8
				cameraOffsetTarget = Vector3.new(0,0,rotationOffset)
			else
				cameraOffsetTarget = Vector3.zero
			end

			xOffset = 0
			yOffset = 0
			zOffset = cameraOffsetTarget.Z

			if stance == 1 then
				yOffset = -1
				if firstPerson then zOffset -= 0.3 end
			elseif stance == 2 then
				yOffset = -1.5
				if firstPerson then zOffset = -1.7 end
			end

			-- Lean offset
			if lean < 0 then
				xOffset = -1
				yOffset += -0.2
			elseif lean > 0 then
				xOffset = 1
				yOffset += -0.2
			end

		else

			if config.firstPersonBody and firstPerson then
				local xHead = character.HumanoidRootPart.CFrame:ToObjectSpace(camera.CFrame):ToEulerAngles()
				local rotationOffset = -1.6 + (xHead + 1.4) / 2.8
				cameraOffsetTarget = Vector3.new(0,0,rotationOffset)
			else
				cameraOffsetTarget = Vector3.zero
			end

			xOffset = 0
			yOffset = 0
			zOffset = cameraOffsetTarget.Z

			if stance == 1 then -- DD_SPH: Adjusted camera positioning to reflect R15.
				yOffset = .5
				if firstPerson then zOffset -= 1.5 end --rev
			elseif stance == 2 then
				yOffset = 1.5
				if firstPerson then zOffset = -3 end --rev
			end

			-- Lean offset
			if lean < 0 then
				xOffset = -1
				yOffset += -0.2 --rev
			elseif lean > 0 then
				xOffset = 1
				yOffset += -0.2 --rev
			end

		end --</DD_SPH>

		if not vehicleSeated and camera.CameraType == Enum.CameraType.Custom then
			-- Update camera offset
			if rigType == Enum.HumanoidRigType.R6 then -- DD_SPH: Different offsets for different rigs
				cameraOffsetTarget = Vector3.new(xOffset,yOffset,zOffset)
			else
				cameraOffsetTarget = Vector3.new(xOffset,-yOffset,zOffset)
			end
			humanoid.CameraOffset = humanoid.CameraOffset:Lerp(cameraOffsetTarget,0.1 * dt * 60)

			-- Update leaning offset
			-- DD_SPH: Rig Check!
			if rigType ~= Enum.HumanoidRigType.R15 then
				rootJoint.C1 = rootJoint.C1:Lerp(CFrame.new(-xOffset / 2,0,0) * CFrame.Angles(math.rad(90),math.rad(180) + math.rad(17 * lean),0),0.1 * dt * 60)
			else
				rootJoint.C1 = rootJoint.C1:Lerp(CFrame.new(-xOffset / 2,0,0) * CFrame.Angles(math.rad(0),math.rad(0), math.rad(0) + math.rad(17 * lean)),0.1 * dt * 60)
			end
			-- </DD_SPH>
			cameraLeanRotation = LerpNumber(cameraLeanRotation,15 * -lean, 0.1)
			camera.CFrame *= CFrame.Angles(0,0,math.rad(cameraLeanRotation))

			-- Camera tilt
			if config.cameraTilting and firstPerson then
				local maxTiltAngle = 2
				local relativeVelocity = humanoidRootPart.CFrame:VectorToObjectSpace(humanoidRootPart.Velocity)
				local mouseDelta = userInputService:GetMouseDelta()
				local targetRollAngle = math.clamp(-relativeVelocity.X, -maxTiltAngle, maxTiltAngle) + mouseDelta.X / 2
				cameraRollAngle = LerpNumber(cameraRollAngle,targetRollAngle,0.07 * dt * 60)
				camera.CFrame *= CFrame.Angles(0,0,math.rad(cameraRollAngle))
			end
		end

		-- Update viewmodel
		if equipped and camera.CameraType == Enum.CameraType.Custom then
			if firstPerson and not viewmodelVisible then
				-- Player switched to first person
				RefreshViewmodel()
				ToggleSprint(sprintHeld)
			end

			-- Update recoil and movement springs
			UpdateViewmodelPosition(dt)

			-- DD_SPH Bipod
			if gunModel.Grip:FindFirstChild("Bipod") then -- factory
				local BipodRay = Ray.new(gunModel.Grip.Bipod.WorldCFrame.Position, Vector3.new(0,-1.5,0))
				local BipodHit, BipodPos, BipodNorm = workspace:FindPartOnRayWithIgnoreList(BipodRay, bipodRayIgnore, false, true)

				if BipodHit then
					canBipod = true
				else
					canBipod = false
				end

				if canBipod and not bipodEnabled then -- deploy bipod if possible
					bipodEnabled = true
					ToggleBipod(gunModel, bipodEnabled)
					PlayRepSound("Switch")
					playerToggleAttachment:Fire(2,bipodEnabled)
				end

				if bipodEnabled and not canBipod then -- undeploy bipod if not possible but still active
					bipodEnabled = false
					ToggleBipod(gunModel, bipodEnabled)
					PlayRepSound("Switch")
					playerToggleAttachment:Fire(2,bipodEnabled)
				end				
			end
			if attStats.Bipod and gunModel[attStats.Bipod].Main:FindFirstChild("Bipod") then
				local BipodRay = Ray.new(gunModel[attStats.Bipod].Main.Bipod.WorldCFrame.Position, Vector3.new(0,-1.5,0))
				local BipodHit, BipodPos, BipodNorm = workspace:FindPartOnRayWithIgnoreList(BipodRay, bipodRayIgnore, false, true)

				if BipodHit then
					canBipod = true
				else
					canBipod = false
				end

				if canBipod and not bipodEnabled then -- deploy bipod if possible
					bipodEnabled = true
					ToggleBipod(gunModel[attStats.Bipod], bipodEnabled)
					PlayRepSound("Switch")
					playerToggleAttachment:Fire(2,bipodEnabled)
				end

				if bipodEnabled and not canBipod then -- undeploy bipod if not possible but still active
					bipodEnabled = false
					ToggleBipod(gunModel[attStats.Bipod], bipodEnabled)
					PlayRepSound("Switch")
					playerToggleAttachment:Fire(2,bipodEnabled)
				end
			end
			-- </DD_SPH>

			-- Laser raycast
			if laserEnabled then
				if not laserDotUI.Enabled then
					laserDotUI.Enabled = true
					-- DD_SPH Gunsmith: Laser
					local lazer
					if attStats.laserOrigin then
						lazer = gunModel[attStats.laserOrigin].Main.Laser
					end
					if gunModel.Grip:FindFirstChild("Laser") then
						lazer = gunModel.Grip.Laser
					end
					laserDotUI.Dot.ImageColor3 = lazer.Color.Value

					if config.laserTrail then
						laserBeamFP.Color = ColorSequence.new(lazer.Color.Value)
						laserBeamTP.Color = ColorSequence.new(lazer.Color.Value)

						if firstPerson then
							laserBeamFP.Enabled = true
						else
							laserBeamTP.Enabled = true
							if not laserBeamTP.Attachment0 then
								if attStats.laserOrigin then
									laserBeamTP.Attachment0 = GetThirdPersonGunModel()[attStats.laserOrigin].Main.Laser
								end
								if gunModel.Grip:FindFirstChild("Laser") then
									laserBeamTP.Attachment0 = GetThirdPersonGunModel().Grip.Laser
								end
							end
						end
					end
					-- </DD_SPH>
				end
				local laserPoint:Attachment-- = firstPerson and gunModel.Grip.Laser or GetThirdPersonGunModel().Grip.Laser
				-- DD_SPH Gunsmith: Layzer
				if gunModel.Grip:FindFirstChild("Laser") then
					laserPoint = firstPerson and gunModel.Grip.Laser or GetThirdPersonGunModel().Grip.Laser
				end
				if attStats.laserOrigin then
					laserPoint = firstPerson and gunModel[attStats.laserOrigin].Main.Laser or GetThirdPersonGunModel()[attStats.laserOrigin].Main.Laser
				end
				if not laserDotPoint then return end
				-- </DD_SPH>
				local laserRayParams = RaycastParams.new()
				laserRayParams.FilterType = Enum.RaycastFilterType.Exclude
				laserRayParams.FilterDescendantsInstances = {gunModel, character}
				laserRayParams.RespectCanCollide = true
				local rayResult = workspace:Raycast(laserPoint.WorldPosition, laserPoint.WorldCFrame.LookVector * 600, laserRayParams)
				if rayResult then
					laserDotPoint.WorldPosition = rayResult.Position
				else
					laserDotPoint.WorldPosition = laserPoint.WorldCFrame.LookVector * 600
				end
			elseif laserDotUI.Enabled then
				laserDotUI.Enabled = false
				laserBeamFP.Enabled = false
				laserBeamTP.Enabled = false
			end

		elseif viewmodelVisible and not equipping then
			viewmodelVisible = false
		end

		-- Update movement sway
		local tempDampening = config.bobDampening
		local difference = tempDampening - (tempDampening / (tempWalkSpeed / config.walkSpeed))
		difference /= 2
		tempDampening -= difference
		if aiming then tempDampening *= config.aimBobDampening end

		local tempBobSpeed = config.bobSpeed
		tempBobSpeed *= tempWalkSpeed / config.walkSpeed

		if not humanoid.Sit then
			local moveSway = Vector3.new(GetSineOffset(tempBobSpeed),GetSineOffset(tempBobSpeed / 2),GetSineOffset(tempBobSpeed / 2))
			moveSpring:shove(moveSway / tempDampening * humanoidRootPart.Velocity.Magnitude / tempDampening * dt * 60)
		end

		local updatedMoveSway = moveSpring:update(dt)
		animBase.CFrame = animBase.CFrame:ToWorldSpace(CFrame.new(updatedMoveSway.Y, updatedMoveSway.X, 0) * CFrame.Angles(updatedMoveSway.Y * 0.3,0,updatedMoveSway.Y * 0.8))

		-- Camera movement sway
		if config.cameraMovement and (firstPerson and not humanoid.Sit) and not vehicleSeated and camera.CameraType == Enum.CameraType.Custom then
			camera.CFrame *= CFrame.Angles(math.rad(updatedMoveSway.X / config.cameraBobDampening), math.rad(updatedMoveSway.Y / config.cameraBobDampening), 0)
		end

		-- Update sights
		for _, sight:BasePart in ipairs(sights) do
			local frame = sight.SurfaceGui.Frame
			local sightUI = frame:FindFirstChild("Reticle") or frame:FindFirstChild("Holo")

			local dist = sight.CFrame:PointToObjectSpace(camera.CFrame.Position)/sight.Size
			sightUI.Position = UDim2.fromScale(0.5 + dist.X, 0.5 - dist.Y)	

			if sightUI.Name == "Holo" then
				local newSize = camera.FieldOfView / 70
				sightUI.Size = UDim2.fromScale(newSize,newSize)
			end
		end

		if aiming then
			camera.FieldOfView = LerpNumber(camera.FieldOfView, aimFOVTarget, 0.3)
		end
	end

	tempWalkSpeed = targetWalkSpeed

	if script:GetAttribute("WalkspeedOverrideToggle") then -- Override walkspeed
		tempWalkSpeed = script:GetAttribute("WalkspeedOverride")
	end

	if humanoid.Health < 30 and config.lowHealthEffects then
		tempWalkSpeed *= humanoid.Health / 30
	end

	humanoid.WalkSpeed = LerpNumber(humanoid.WalkSpeed, tempWalkSpeed, 0.2 * dt * 60)

	-- Prone angle
	if stance == 2 and config.proneAngle then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = {character}
		params.IgnoreWater = true
		params.RespectCanCollide = true

		local rayResult = workspace:Raycast(humanoidRootPart.Position, Vector3.new(0, -2, 0), params)
		if rayResult and rayResult.Instance then
			--print(rayResult.Normal.X)
			--rootJoint.C0 *= CFrame.Angles(rayResult.Normal.X, 0, 0)
			--rootJoint.C0 *= CFrame.Angles(rayResult.Normal.X, rayResult.Normal.Y, rayResult.Normal.Z)
			--print(rootJoint.C0, rootJoint.C1, rayResult.Normal)

			local rotateToFloorCFrame = GetRotationBetween(humanoidRootPart.CFrame.UpVector, rayResult.Normal, Vector3.new(1, 0, 0))
			rootJoint.C0 *= CFrame.Angles(rotateToFloorCFrame.X, rotateToFloorCFrame.Y, rotateToFloorCFrame.Z)
			--print(rotateToFloorCFrame.UpVector)
			local goalCF = rotateToFloorCFrame * humanoidRootPart.CFrame
			--wedge.CFrame = wedge.CFrame:Lerp(goalCF, 5 * dt).Rotation + wedge.CFrame.Position
		end
	end
end)

InputController.ScrollFired = function(scrollAmount, holdForZoom)
	if aiming then
		if holdForZoom then
			-- Zoom
			local newFOV = aimFOVTarget - scrollAmount * 3
			-- DD_SPH Gunsmith: FOV adjusts with scope
			local aimFovMinTarget = wepStats.aimFovMin
			local aimFovMaxTarget = wepStats.aimFovMax or defaultFOV
			if attStats.aimFovMin then aimFovMinTarget = attStats.aimFovMin end
			if attStats.aimFovMax then aimFovMaxTarget = attStats.aimFovMax end
			aimFOVTarget = math.clamp(newFOV, aimFovMinTarget, aimFovMaxTarget)
			-- </DD_SPH>
		else
			-- Sensitivity
			aimSensitivity = math.clamp(aimSensitivity - 0.01 * -scrollAmount,0.005,1)
			wepStats.aimSpeed = aimSensitivity
			userInputService.MouseDeltaSensitivity = aimSensitivity
		end
	end
end

humanoid.Seated:Connect(function(seated, seatPart)
	if seated then -- In a seat
		InputController.UnbindCharacterInputs()
		ToggleSprint(false)
		ChangeLean(0)
		if stance == 1 then
			ChangeStance(-1)
		elseif stance == 2 then
			ChangeStance(-1)
			ChangeStance(-1)
		end

		if seatPart:IsA("VehicleSeat") then
			vehicleSeated = true
			if equipped then
				humanoid:UnequipTools()
			end
		else
			vehicleSeated = false
		end
	else -- Exiting a seat
		InputController.BindCharacterInputs()
		vehicleSeated = false
	end
end)

local canJump = true

InputController.JumpRequested = function()
	if humanoid.Sit then
		character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	elseif stance == 0 then
		if character.Humanoid.FloorMaterial == Enum.Material.Air then return end
		if canJump then
			canJump = false
			character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			task.wait(config.jumpCooldown)
			canJump = true
		else
			character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		end
	else
		character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	end
end