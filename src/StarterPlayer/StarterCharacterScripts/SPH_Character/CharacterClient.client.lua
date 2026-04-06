local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")
local userInputService = game:GetService("UserInputService")
local debris = game:GetService("Debris")
local players = game:GetService("Players")
local Enums = require(script.Parent:WaitForChild("Enums"))
local Intents = Enums.Intents
local assets = replicatedStorage.SPH_Assets
local modules = assets.Modules
local config = require(assets.GameConfig)
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

local weldMod = require(modules.WeldMod)
local bridgeNet = require(modules.BridgeNet)
local viewMod = require(modules.ViewMod)
local springMod = require(modules.SpringModule)
local hitFX = require(modules.HitFX)
local shellEjection = require(modules.ShellEjection)
local bulletHandler = require(modules.BulletHandler)
local callbacks = require(assets.Mods)
local Packages = replicatedStorage.Packages
local Charm = require(Packages.Charm)

local Controllers = script.Parent:WaitForChild("Controllers")
local State = require(Controllers:WaitForChild("CharacterState"))
local WeaponState = require(Controllers:WaitForChild("WeaponState"))
local InputController = require(Controllers:WaitForChild("InputController"))
local ViewmodelController = require(Controllers:WaitForChild("ViewmodelController"))
local MovementController = require(Controllers:WaitForChild("MovementController"))
local AnimationController = require(Controllers:WaitForChild("AnimationController"))
local WeaponController = require(Controllers:WaitForChild("WeaponController"))
local CameraController = require(Controllers:WaitForChild("CameraController"))
local ReplicationController = require(Controllers:WaitForChild("ReplicationController"))
local UIController = require(Controllers:WaitForChild("UIController"))

bulletHandler.Initialize(player)

local warnPrefix = "【 SPEARHEAD 】 "
humanoid.WalkSpeed = config.walkSpeed

local sphWorkspace = workspace:WaitForChild("SPH_Workspace")
local shellFolder = sphWorkspace:WaitForChild("Shells")

local rayParams = RaycastParams.new()
rayParams.IgnoreWater = true
rayParams.RespectCanCollide = true
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.FilterDescendantsInstances = {character,camera,shellFolder}

local playCharSound = bridgeNet.CreateBridge("PlayCharacterSound")

local storageCFrame = CFrame.new(1000000,0,0) -- This is used for moving the viewmodel super far away.
-- Doing this to the viewmodel allows animations to be loaded, played, etc, while still having it out of view.

-- DD_SPH: Get the character's rig type to determine what animation folder to load from.
if rigType == Enum.HumanoidRigType.R15 then
	animations = assets.Animations.R15
else
	animations = assets.Animations.R6
end
-- </DD_SPH>

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
local rig = viewMod.RigModel(player)

if State.Parts.IsR6 then -- DD_SPH: Easy coloring
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

-- DD_SPH Gunsmith
local gunsmith = require(modules.Gunsmith)
WeaponState.attStats = gunsmith.attStats

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

AnimationController.Initialize({
	vmAnimator = vmAnimator,
	characterAnimator = characterAnimator,
	animationsFolder = animations,
	OnKeyframeReached = WeaponController.OnKeyframeReached,
	OnAnimationStopped = WeaponController.OnAnimationStopped
})

-- Makes the viewmodel visible and refreshes its appearance
local function RefreshViewmodel()
	if State.firstPerson() then
		WeaponState.viewmodelVisible(true)
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

	if callbacks.onViewmodelRefresh then callbacks.onViewmodelRefresh(player,rig) end
end

local function OnScrollIntent(scrollAmount, holdForZoom)
	if State.aiming() then
		--[[
		NOTE: This can be added at a future time

		if holdForZoom then
			-- Zoom
			local newFOV = WeaponController.aimFOVTarget - scrollAmount * 3
			-- DD_SPH Gunsmith: FOV adjusts with scope
			local aimFovMinTarget = State.wepStats.aimFovMin
			local aimFovMaxTarget = State.wepStats.aimFovMax or config.defaultFOV
			if State.attStats.aimFovMin then aimFovMinTarget = State.attStats.aimFovMin end
			if State.attStats.aimFovMax then aimFovMaxTarget = State.attStats.aimFovMax end
			WeaponController.aimFOVTarget = math.clamp(newFOV, aimFovMinTarget, aimFovMaxTarget)
			-- </DD_SPH>
		else

		end]]

		-- Sensitivity
		WeaponState.aimSens(math.clamp(WeaponState.aimSens() + (0.01 * scrollAmount), 0.01, 1))
		WeaponState.wepStats.aimSpeed = WeaponState.aimSens()
	else
		if not WeaponState.canManipulate() then
			return
		end
		WeaponState.holdStance(math.clamp(WeaponState.holdStance() + (scrollAmount > 0 and -1 or 1),
			Enums.HoldStance.High,
			Enums.HoldStance.Patrol))
	end
end

InputController.Initialize({
	callbacks = {
		[Intents.SPRINT] = MovementController.OnSprintIntent,
		[Intents.STANCE_DOWN] = MovementController.OnStanceDownIntent,
		[Intents.STANCE_UP] = MovementController.OnStanceUpIntent,
		[Intents.LEAN_LEFT] = MovementController.OnLeanLeftIntent,
		[Intents.LEAN_RIGHT] = MovementController.OnLeanRightIntent,
		[Intents.JUMP] = MovementController.Jump,

		[Intents.FREELOOK] = CameraController.OnFreelookIntent,
		[Intents.SCROLL] = OnScrollIntent,


		[Intents.HOLD_AIM] = WeaponController.OnAimIntent,
		[Intents.TRIGGER] = WeaponController.OnTriggerIntent,
		[Intents.DROP_GUN] = WeaponController.OnDropGunIntent,
		[Intents.RELOAD] = WeaponController.OnReloadIntent,
		[Intents.CHAMBER] = WeaponController.OnChamberIntent,
		[Intents.SWITCH_SIGHTS] = WeaponController.OnSwitchSightsIntent,
		[Intents.SWITCH_FIRE_MODE] = WeaponController.OnSwitchFireModeIntent,
		[Intents.TOGGLE_LASER] = WeaponController.OnToggleLaserIntent,
		[Intents.TOGGLE_FLASHLIGHT] = WeaponController.OnToggleFlashlightIntent,
	}
})

MovementController.Initialize({
	humanoid = humanoid,
	humanoidRootPart = humanoidRootPart,
	rootJoint = rootJoint,
	rigType = rigType,
	script = script,
	ChangeHoldStance = WeaponController.ChangeHoldStance,
	PlayAnimation = AnimationController.PlayAnimation,
	StopAnimation = AnimationController.StopAnimation,
	AdjustMoveAnimSpeed = AnimationController.AdjustMoveAnimSpeed,
	PlayCharSound = PlayCharSound,
})

ViewmodelController.Initialize({
	animBase = animBase,
	camera = camera,
	humanoidRootPart = humanoidRootPart,
	weaponRig = weaponRig,
	rayParams = rayParams,
	ChangeHoldStance = WeaponController.ChangeHoldStance,
	PlayAnimation = AnimationController.PlayAnimation,
	StopAnimation = AnimationController.StopAnimation,
	RefreshViewmodel = RefreshViewmodel,
})

CameraController.Initialize({
	camera = camera,
	character = character,
	humanoid = humanoid,
	humanoidRootPart = humanoidRootPart,
	rootJoint = rootJoint,
	neckJoint = neckJoint,
	rigType = rigType,
	MovementController = MovementController,
	ReplicationController = ReplicationController,
})

WeaponController.Initialize({
	player = player,
	character = character,
	humanoid = humanoid,
	humanoidRootPart = humanoidRootPart,
	camera = camera,
	viewmodelRig = rig,
	thirdPersonRig = weaponRig,
	rigType = rigType,
	laserDotUI = laserDotUI,
	laserDotPoint = laserDotPoint,
	laserBeamFP = laserBeamFP,
	laserBeamTP = laserBeamTP,
	AnimationController = AnimationController,
	ViewmodelController = ViewmodelController,
	MovementController = MovementController,
	InputController = InputController,
	RefreshViewmodel = RefreshViewmodel,
})

ReplicationController.Initialize({
	character = character
})

UIController.Initialize({})

InputController.BindCharacterInputs()

humanoid.Died:Connect(function()
	State.dead(true)
	if State.equippedTool() then
		WeaponController.Unequip(State.equippedTool())
	end
	userInputService.MouseIconEnabled = true
	WeaponState.viewmodelVisible(false)
	animBase.CFrame = storageCFrame

	InputController.UnbindGunInputs()

	if config.useDeathCameraSubject then
		repeat task.wait() until humanoid.Parent ~= character
		camera.CameraSubject = humanoid
	end

	if rig then rig:Destroy() end
end)

runService.RenderStepped:Connect(function(dt:number)
	if math.ceil(1 / dt) < 5 then -- Skip the render stepped function if FPS is lower than 5 to avoid stuttering issues
		print(warnPrefix.."RenderStepped skipped due to low framerate.")
		return
	end

	if not State.dead() and character:FindFirstChild("Head") then
		MovementController.UpdateRender(dt)
		CameraController.UpdateRender(dt)
		ViewmodelController.UpdateRender(dt)
		WeaponController.UpdateRender(dt)
		CameraController.UpdateFOV(dt)
	end

	ViewmodelController.UpdateMovementSway(dt, MovementController.tempWalkSpeed, MovementController.vehicleSeated)
end)

runService.Heartbeat:Connect(function(dt:number)
	MovementController.UpdateHeartbeat(dt)
	WeaponController.UpdateHeartbeat(dt)
	UIController.UpdateHeartbeat(dt)
end)
