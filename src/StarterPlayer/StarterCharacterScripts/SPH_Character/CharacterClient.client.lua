local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")
local userInputService = game:GetService("UserInputService")
local debris = game:GetService("Debris")
local players = game:GetService("Players")
local tweenService = game:GetService("TweenService")

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

local Controllers = script.Parent:WaitForChild("Controllers")
local State = require(Controllers:WaitForChild("CharacterState"))
local InputController = require(Controllers:WaitForChild("InputController"))
local ViewmodelController = require(Controllers:WaitForChild("ViewmodelController"))
local MovementController = require(Controllers:WaitForChild("MovementController"))
local AnimationController = require(Controllers:WaitForChild("AnimationController"))
local WeaponController = require(Controllers:WaitForChild("WeaponController"))
local CameraController = require(Controllers:WaitForChild("CameraController"))

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

local bodyAnimRequest = bridgeNet.CreateBridge("BodyAnimRequest")
local playCharSound = bridgeNet.CreateBridge("PlayCharacterSound")
local playerLean = bridgeNet.CreateBridge("PlayerLean")

local fpThreshold = 0.6

local depthOfField = game.Lighting:FindFirstChild("SPH_DoF")
if not depthOfField and config.blurEffects then
	depthOfField = Instance.new("DepthOfFieldEffect",game.Lighting)
end
if depthOfField then depthOfField.Name = "SPH_DoF" end

local viewmodelVisible = false
local blocked = false
local sprintHeld = false
local aimHeld = false

local freeLook = false
local freeLookOffset = CFrame.new()
local freeLookRotation = CFrame.new()

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

-- DD_SPH Gunsmith
local gunsmith = require(modules.Gunsmith)
State.attStats = gunsmith.attStats

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
	if State.firstPerson and not WeaponController.equipping then
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

	WeaponController.IdleAnim()

	if callbacks.onViewmodelRefresh then callbacks.onViewmodelRefresh(player,rig) end
end

-- Remove rig and reset head orientation
local function ResetHead()
	viewmodelVisible = false
end

local function LerpNumber(number:number, target:number, speed:number)
	return number + (target-number) * speed
end

local function ToggleAiming(toggle)
	State.aiming(toggle)
	character:SetAttribute("Aiming", toggle)
end


local function ChangeDoF(fInt,fDist,fRad,nInt)
	if not depthOfField then return end
	tweenService:Create(depthOfField,TweenInfo.new(0.2),{
		FarIntensity = fInt,
		FocusDistance = fDist,
		InFocusRadius = fRad,
		NearIntensity = nInt
	}):Play()
end

local function HandleInput(actionName, inputState, inputObject)
	local inputBegan = Enum.UserInputState.Begin
	local inputEnded = Enum.UserInputState.End


	if actionName == "SPH_Sprint" then -- Sprint hold
		sprintHeld = inputState == inputBegan
		if sprintHeld and State.stance < 2 and MovementController.moving then -- Begin State.sprinting
			if State.stance == 1 then MovementController.ChangeStance(-1) end
			if State.equipped and MovementController.moving then MovementController.ToggleSprint(true) end
			MovementController.ChangeWalkSpeed(config.sprintSpeed)
			MovementController.ChangeLean(0)
		elseif State.stance == 0 then -- End State.sprinting
			MovementController.ToggleSprint(false)
			MovementController.ChangeWalkSpeed(config.walkSpeed)
		end
	elseif inputState == inputBegan then -- Other inputs

		if actionName == "SPH_StanceLower" and inputState == inputBegan and State.stance < 2 and not humanoid.Sit then -- Lower State.stance
			if not config.canProne and State.stance == 1 then return end -- If the player is crouched and unable to prone then return
			MovementController.ChangeStance(1)
			if State.sprinting() then MovementController.ToggleSprint(false) end


		elseif actionName == "SPH_StanceRaise" and inputState == inputBegan and State.stance > 0 then -- Raise State.stance
			MovementController.ChangeStance(-1)


		elseif actionName == "SPH_LeanLeft" and inputState == inputBegan and State.stance < 2 and not State.sprinting() and not humanoid.Sit then -- Lean left
			if MovementController.lean == -1 then
				MovementController.ChangeLean(0)
			else
				MovementController.ChangeLean(-1)
			end


		elseif actionName == "SPH_LeanRight" and inputState == inputBegan and State.stance < 2 and not State.sprinting() and not humanoid.Sit then -- Lean right
			if MovementController.lean == 1 then
				MovementController.ChangeLean(0)
			else
				MovementController.ChangeLean(1)
			end
		end
	end


	if actionName == "SPH_HoldAim" then
		if not userInputService.TouchEnabled and not config.toggleAiming then -- Hold aiming
			if inputState == inputBegan and State.firstPerson and not freeLook and not blocked then
				aimHeld = true
				MovementController.ToggleSprint(false)
				if State.stance == 0 then MovementController.ChangeWalkSpeed(config.walkSpeed) end
				ToggleAiming(true)
			elseif not State.sprinting() and State.aiming() then -- Not aiming
				aimHeld = false
				ToggleAiming(false)
			end
		elseif inputState == inputBegan then -- Mobile and toggle aiming
			if State.firstPerson and not freeLook and not blocked and not State.aiming() then
				aimHeld = true
				MovementController.ToggleSprint(false)
				if State.stance == 0 then MovementController.ChangeWalkSpeed(config.walkSpeed) end
				ToggleAiming(true)
			else
				aimHeld = false
				ToggleAiming(false)
			end
		end
	elseif State.equipped then
		WeaponController.HandleInput(actionName, inputState)
	end
	
	if actionName == "SPH_Freelook" then -- Freelook
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
	end
end

MovementController.Initialize({
	humanoid = humanoid,
	humanoidRootPart = humanoidRootPart,
	rootJoint = rootJoint,
	rigType = rigType,
	depthOfField = depthOfField,
	script = script,
	crouchIdleAnim = crouchIdleAnim,
	crouchMoveAnim = crouchMoveAnim,
	proneIdleAnim = proneIdleAnim,
	proneMoveAnim = proneMoveAnim,
	ToggleAiming = ToggleAiming,
	ChangeHoldStance = WeaponController.ChangeHoldStance,
	PlayAnimation = AnimationController.PlayAnimation,
	StopAnimation = AnimationController.StopAnimation,
	PlayCharSound = PlayCharSound,
	playerLean = playerLean,
	ChangeDoF = ChangeDoF,
	CancelFiring = function() WeaponController.holdingM1 = false end
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
	ToggleAiming = ToggleAiming
})

CameraController.Initialize({
	camera = camera,
	character = character,
	humanoid = humanoid,
	humanoidRootPart = humanoidRootPart,
	rootJoint = rootJoint,
	rigType = rigType,
	MovementController = MovementController,
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
	ToggleAiming = ToggleAiming,
	ChangeDoF = ChangeDoF,
	GetSprintHeld = function() return sprintHeld end
})

InputController.ActionFired = HandleInput
InputController.BindCharacterInputs()

humanoid.Died:Connect(function()
	State.dead = true
	WeaponController.switchWeapon:Fire()
	State.equipped = nil
	State.wepStats = nil
	State.attStats = {} -- DD_SPH: Gunsmith
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

local headRotationEventCooldown = 0
runService.RenderStepped:Connect(function(dt:number)
	if math.ceil(1 / dt) < 5 then -- Skip the render stepped function if FPS is lower than 5 to avoid stuttering issues
		print(warnPrefix.."RenderStepped skipped due to low framerate.")
		return
	end

	headRotationEventCooldown -= dt

	if not State.dead and character:FindFirstChild("Head") then
		if not State.dead then
			local torsoDirection
			if humanoid.RigType == Enum.HumanoidRigType.R6 then
				torsoDirection = character.Torso.CFrame.LookVector
			else
				torsoDirection = character.UpperTorso.CFrame.LookVector
			end

			local lookDirection = camera.CFrame
			if (not config.headRotation or State.sprinting()) and not State.firstPerson then
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

			if headRotationEventCooldown <= 0 and not State.dead and not config.disableHeadRotation then
				headRotationEventCooldown = config.headRotationEventRate
				bodyAnimRequest:Fire(neckJoint.C1)
			end
		end

		-- Check if player is in first person
		if not State.firstPerson and character.Head.LocalTransparencyModifier >= fpThreshold then
			State.firstPerson = true
			if State.equipped then
				InputController.BindAiming()
				if WeaponController.flashlightEnabled then
					if State.gunModel.Grip:FindFirstChild("Flashlight") then
						State.gunModel.Grip.Flashlight:FindFirstChildWhichIsA("Light").Enabled = true
						weaponRig.Weapon:FindFirstChildWhichIsA("Model").Grip.Flashlight:FindFirstChildWhichIsA("Light").Enabled = false
					end
					-- DD_SPH Gunsmith
					if State.attStats.flashlights_client then
						for _, lightAttachment in ipairs(State.attStats.flashlights_client) do
							lightAttachment.Main.Flashlight:FindFirstChildWhichIsA("Light").Enabled = true
							weaponRig.Weapon:FindFirstChildWhichIsA("Model")[lightAttachment.Name].Main.Flashlight:FindFirstChildWhichIsA("Light").Enabled = false
						end
					end
					-- </DD_SPH>
				end
				if WeaponController.laserEnabled then
					laserBeamTP.Enabled = false
					laserBeamFP.Enabled = true
				end
			end
		elseif State.firstPerson and character.Head.LocalTransparencyModifier <= fpThreshold then
			State.firstPerson = false
			InputController.UnbindAiming()
			if State.equipped then
				if WeaponController.laserEnabled then
					laserBeamTP.Enabled = true
					laserBeamFP.Enabled = false
					if not laserBeamTP.Attachment0 then
						laserBeamTP.Attachment0 = weaponRig.Weapon:FindFirstChildWhichIsA("Model").Grip.Laser
					end
					-- DD_SPH Gunsmith: Laser
					if State.attStats.laserOrigin and State.gunModel[State.attStats.laserOrigin].Main:FindFirstChild("Laser") then
						laserBeamTP.Attachment0 = weaponRig.Weapon:FindFirstChildWhichIsA("Model")[State.attStats.laserOrigin].Main.Laser		
					end
				end
				if State.gunModel.Grip:FindFirstChild("Flashlight") then
					State.gunModel.Grip.Flashlight:FindFirstChildWhichIsA("Light").Enabled = false
					if weaponRig.Weapon:FindFirstChildWhichIsA("Model") and WeaponController.flashlightEnabled then
						weaponRig.Weapon:FindFirstChildWhichIsA("Model").Grip.Flashlight:FindFirstChildWhichIsA("Light").Enabled = true
					end
				end
				-- DD_SPH Gunsmith
				if State.attStats.flashlights_client then
					for _, lightAttachment in ipairs(State.attStats.flashlights_client) do
						lightAttachment.Main.Flashlight:FindFirstChildWhichIsA("Light").Enabled = false
						if weaponRig.Weapon:FindFirstChildWhichIsA("Model") and WeaponController.flashlightEnabled then
							weaponRig.Weapon:FindFirstChildWhichIsA("Model")[lightAttachment].Main.Flashlight:FindFirstChildWhichIsA("Light").Enabled = true
						end
					end
				end
				-- </DD_SPH>
			end
			ResetHead()
			CameraController.cameraOffsetTarget = Vector3.zero
		end

		MovementController.UpdateRender(dt)
		CameraController.UpdateRender(dt, freeLook)

		-- Update viewmodel
		if State.equipped and camera.CameraType == Enum.CameraType.Custom then
			if State.firstPerson and not viewmodelVisible then
				-- Player switched to first person
				RefreshViewmodel()
				MovementController.ToggleSprint(sprintHeld)
			end

			-- Update recoil and movement springs
			local currentOffset = State.wepStats and State.wepStats.viewmodelOffset or CFrame.new()
			freeLookOffset, blocked = ViewmodelController.UpdateViewmodelPosition(dt, currentOffset, freeLook, freeLookRotation, freeLookOffset, WeaponController.sightIndex, blocked, aimHeld, viewmodelVisible)

			WeaponController.UpdateRender(dt)

		elseif viewmodelVisible and not WeaponController.equipping then
			viewmodelVisible = false
		end

		ViewmodelController.UpdateMovementSway(dt, MovementController.tempWalkSpeed, MovementController.vehicleSeated)

		-- TODO: move this to WeaponController
		for _, sight:BasePart in ipairs(WeaponController.sights) do
			local frame = sight.SurfaceGui.Frame
			local sightUI = frame:FindFirstChild("Reticle") or frame:FindFirstChild("Holo")

			local dist = sight.CFrame:PointToObjectSpace(camera.CFrame.Position)/sight.Size
			sightUI.Position = UDim2.fromScale(0.5 + dist.X, 0.5 - dist.Y)	

			if sightUI.Name == "Holo" then
				local newSize = camera.FieldOfView / 70
				sightUI.Size = UDim2.fromScale(newSize,newSize)
			end
		end

		CameraController.UpdateFOV(dt)
	end

end)

runService.Heartbeat:Connect(function(dt:number)
	MovementController.UpdateHeartbeat(dt)
	WeaponController.UpdateHeartbeat(dt, freeLook, blocked)

	-- TODO: figure out wtf this does
	if State.stance == 2 and config.proneAngle then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = {character}
		params.IgnoreWater = true
		params.RespectCanCollide = true

		local rayResult = workspace:Raycast(humanoidRootPart.Position, Vector3.new(0, -2, 0), params)
		if rayResult and rayResult.Instance then
			local dot, uxv = humanoidRootPart.CFrame.UpVector:Dot(rayResult.Normal), humanoidRootPart.CFrame.UpVector:Cross(rayResult.Normal)
			local rotateToFloorCFrame = (dot < -0.99999) and CFrame.fromAxisAngle(Vector3.new(1,0,0), math.pi) or CFrame.new(0, 0, 0, uxv.x, uxv.y, uxv.z, 1 + dot)
			rootJoint.C0 *= CFrame.Angles(rotateToFloorCFrame.X, rotateToFloorCFrame.Y, rotateToFloorCFrame.Z)
		end
	end


end)

InputController.ScrollFired = function(scrollAmount, holdForZoom)
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
		State.aimSens(math.clamp(State.aimSens() + (0.01 * scrollAmount), 0.01, 1))
		State.wepStats.aimSpeed = State.aimSens()
	end
end

humanoid.Seated:Connect(function(seated, seatPart)
	if seated then -- In a seat
		InputController.UnbindCharacterInputs()
		MovementController.ToggleSprint(false)
		MovementController.ChangeLean(0)
		if State.stance == 1 then
			MovementController.ChangeStance(-1)
		elseif State.stance == 2 then
			MovementController.ChangeStance(-1)
			MovementController.ChangeStance(-1)
		end

		if seatPart:IsA("VehicleSeat") then
			MovementController.vehicleSeated = true
			if State.equipped then
				humanoid:UnequipTools()
			end
		else
			MovementController.vehicleSeated = false
		end
	else -- Exiting a seat
		InputController.BindCharacterInputs()
		MovementController.vehicleSeated = false
	end
end)

InputController.JumpRequested = function()
	MovementController.Jump()
end