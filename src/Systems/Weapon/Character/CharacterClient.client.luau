require("@game/ReplicatedStorage/Packages/Charm").flags.frozen = false

local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")
local userInputService = game:GetService("UserInputService")
local debris = game:GetService("Debris")
local players = game:GetService("Players")
local Framework = replicatedStorage.Systems.Weapon
local Access = require(Framework.Access)
local assets = Access.assets
local Enums = require(Framework.Core.Enums)
local Intents = Enums.Intents
local config = Access.config
local player = players.LocalPlayer
local character = script:FindFirstAncestorWhichIsA("Model") :: Model
local characterState = require(Framework.State.CharacterState).new(character)
local humanoid = characterState.Parts.Humanoid
local humanoidRootPart = characterState.Parts.HRP
local animations = characterState.Parts.IsR6 and assets.Animations.R6 or assets.Animations.R15

local camera = workspace.CurrentCamera
if camera.CameraSubject ~= humanoid then
	camera.CameraSubject = humanoid
end
camera.CameraType = Enum.CameraType.Custom
if camera:FindFirstChild("WeaponRig") then
	camera.WeaponRig:Destroy()
end

local Controllers = script.Parent:WaitForChild("Controllers")
local AnimationController = require(Controllers:WaitForChild("AnimationController"))
local CameraController = require(Controllers:WaitForChild("CameraController"))
local EffectController = require(Controllers:WaitForChild("EffectController"))
local InputController = require(Controllers:WaitForChild("InputController"))
local MovementController = require(Controllers:WaitForChild("MovementController"))
local ReplicationController = require(Controllers:WaitForChild("ReplicationController"))
local UIController = require(Controllers:WaitForChild("UIController"))
local ViewmodelController = require(Controllers:WaitForChild("ViewmodelController"))
local WeaponController = require(Controllers:WaitForChild("WeaponController"))
local localEvents = require(Controllers:WaitForChild("LocalEvents"))()

local NetworkEvents = require(Framework.Network.NetworkEvents)
local P = NetworkEvents.packets

local viewMod = require(Framework.Weapons.ViewMod)
local bulletHandler = require(Framework.Ballistics.BulletHandler)
local Packages = replicatedStorage.Packages
local Charm = require(Packages.Charm)

local weaponState = require(Framework.State.WeaponState).new()
local EffectManager = require(Framework.UI.Logic.EffectManager)
local WeaponPrefs = require(Framework.Weapons.WeaponPrefsClient)
local LaserMod = require(Framework.Weapons.Mods.LaserMod)

bulletHandler.Initialize(player)

humanoid.WalkSpeed = config.walkSpeed

local sphWorkspace = workspace:WaitForChild("SPH_Workspace")
local shellFolder = sphWorkspace:WaitForChild("Shells")

local rayParams = RaycastParams.new()
rayParams.IgnoreWater = true
rayParams.RespectCanCollide = true
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.FilterDescendantsInstances = { character, camera, shellFolder }

local function playCharSound(soundType: string)
	P.PlayCharacterSound.send({ soundType = soundType })
end

local storageCFrame = CFrame.new(1000000, 0, 0) -- This is used for moving the viewmodel super far away.
-- Doing this to the viewmodel allows animations to be loaded, played, etc, while still having it out of view.

-- Disable default death sound
if humanoidRootPart:FindFirstChild("Died") then
	humanoidRootPart.Died.Volume = 0
end

-- Unlock the camera in case something went wrong
player.CameraMode = Enum.CameraMode.Classic

-- Create new viewmodel
local rig = viewMod.RigModel(player)

if characterState.Parts.IsR6 then -- DD_SPH: Easy coloring
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
	local bodyparts = { "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand" } -- DD_SPH: List of bodyparts for easy iterating
	for i = 1, #bodyparts do
		rig[bodyparts[i]].Color = character[bodyparts[i]].Color
	end
end -- </DD_SPH>

-- Set up an animator
local vmHuman = Instance.new("Humanoid", rig)

vmHuman.RigType = humanoid.RigType

for _, state in ipairs(Enum.HumanoidStateType:GetEnumItems()) do
	if state == Enum.HumanoidStateType.None then
		continue
	end -- The 'None' state needs to be skipped because it cannot be disabled
	vmHuman:SetStateEnabled(state, false)
end

local vmAnimator = Instance.new("Animator", vmHuman)
local vmShirt = Instance.new("Shirt", rig)
local animBase = rig.AnimBase
animBase.CFrame = storageCFrame

rig.Parent = camera

local weaponRig = character:FindFirstChild("WeaponRig") or character:WaitForChild("WeaponRig")
local characterAnimator: Animator = weaponRig:WaitForChild("AnimationController").Animator

local function PlayCharSound(soundType)
	local soundFolder = assets.Sounds:FindFirstChild(soundType)
	if soundFolder then
		local soundList = soundFolder:GetChildren()
		local newSound = soundList[math.random(#soundList)]:Clone()
		newSound.Parent = humanoidRootPart
		newSound:Play()
		debris:AddItem(newSound, newSound.TimeLength)
		playCharSound(soundType)
	end
end

local animationController = AnimationController.new({
	vmAnimator = vmAnimator,
	characterAnimator = characterAnimator,
	animationsFolder = animations,
	weaponState = weaponState,
	state = characterState,
	events = localEvents,
})

local movementController = MovementController.new({
	humanoid = humanoid,
	humanoidRootPart = humanoidRootPart,
	weaponState = weaponState,
	state = characterState,
	AdjustMoveAnimSpeed = function(speed)
		animationController:AdjustMoveAnimSpeed(speed)
	end,
	PlayCharSound = PlayCharSound,
})

local cameraController = CameraController.new({
	camera = camera,
	weaponState = weaponState,
	state = characterState,
})

local weaponController = WeaponController.new({
	player = player,
	character = character,
	humanoid = humanoid,
	humanoidRootPart = humanoidRootPart,
	camera = camera,
	viewmodelRig = rig,
	thirdPersonRig = weaponRig,
	weaponState = weaponState,
	state = characterState,
	events = localEvents,
})

local viewmodelController = ViewmodelController.new({
	animBase = animBase,
	camera = camera,
	humanoidRootPart = humanoidRootPart,
	weaponRig = weaponRig,
	rayParams = rayParams,
	weaponState = weaponState,
	state = characterState,
	StopAnimation = function(animName, transTime)
		animationController:StopAnimation(animName, transTime)
	end,
	player = player,
	viewmodelRig = rig,
	vmShirt = vmShirt,
})

local replicationController = ReplicationController.new({
	character = character,
	state = characterState,
})

local effectManager = EffectManager.new(characterState.suppressionFactor, config.suppressionRecovery)

local uiController = UIController.new({
	state = characterState,
	weaponState = weaponState,
})
local effectController = EffectController.new({
	state = characterState,
	weaponState = weaponState,
	effectManager = effectManager,
}):Wire(localEvents)

local function OnScrollIntent(scrollAmount, holdForZoom)
	if characterState.aiming() then
		-- Sensitivity
		local currentSens = WeaponPrefs.getGlobal("aimSens")
		WeaponPrefs.setGlobal("aimSens", math.clamp(currentSens + (0.01 * scrollAmount), 0.01, 1))
	else
		if not weaponState.canManipulate() then
			return
		end
		weaponState.holdStance(
			math.clamp(
				weaponState.holdStance() + (scrollAmount > 0 and -1 or 1),
				Enums.HoldStance.High,
				Enums.HoldStance.Patrol
			)
		)
	end
end

local inputController = InputController.new({
	callbacks = {
		[Intents.SPRINT] = function(inputState, inputObject)
			movementController:OnSprintIntent(inputState, inputObject)
		end,
		[Intents.STANCE_DOWN] = function(inputState, inputObject)
			movementController:OnStanceDownIntent(inputState, inputObject)
		end,
		[Intents.STANCE_UP] = function(inputState, inputObject)
			movementController:OnStanceUpIntent(inputState, inputObject)
		end,
		[Intents.LEAN_LEFT] = function(inputState, inputObject)
			movementController:OnLeanLeftIntent(inputState, inputObject)
		end,
		[Intents.LEAN_RIGHT] = function(inputState, inputObject)
			movementController:OnLeanRightIntent(inputState, inputObject)
		end,
		[Intents.JUMP] = function()
			movementController:Jump()
		end,

		[Intents.FREELOOK] = function(inputState, inputObject)
			cameraController:OnFreelookIntent(inputState, inputObject)
		end,
		[Intents.SCROLL] = OnScrollIntent,

		[Intents.HOLD_AIM] = function(inputState, inputObject)
			weaponController:OnAimIntent(inputState, inputObject)
		end,
		[Intents.TRIGGER] = function(inputState, inputObject)
			weaponController:OnTriggerIntent(inputState, inputObject)
		end,
		[Intents.DROP_GUN] = function(inputState, inputObject)
			weaponController:OnDropGunIntent(inputState, inputObject)
		end,
		[Intents.RELOAD] = function(inputState, inputObject)
			weaponController:OnReloadIntent(inputState, inputObject)
		end,
		[Intents.CHAMBER] = function(inputState, inputObject)
			weaponController:OnChamberIntent(inputState, inputObject)
		end,
		[Intents.SWITCH_SIGHTS] = function(inputState, inputObject)
			weaponController:OnSwitchSightsIntent(inputState, inputObject)
		end,
		[Intents.SWITCH_FIRE_MODE] = function(inputState, inputObject)
			weaponController:OnSwitchFireModeIntent(inputState, inputObject)
		end,
		[Intents.TOGGLE_FLASHLIGHT] = function(inputState, inputObject)
			weaponController:OnToggleFlashlightIntent(inputState, inputObject)
		end,
	},
})

local laserMod = LaserMod.new({
	state = characterState,
	weaponState = weaponState,
	Controllers = {
		InputController = inputController,
		WeaponController = weaponController,
	},
})

inputController:BindCharacterInputs()
inputController:BindGunInputs()

humanoid.Died:Connect(function()
	characterState.dead(true)
	if characterState.equippedTool() then
		weaponController:Unequip(characterState.equippedTool())
	end
	userInputService.MouseIconEnabled = true
	weaponState.viewmodelVisible(false)
	animBase.CFrame = storageCFrame

	inputController:UnbindGunInputs()

	if config.useDeathCameraSubject then
		repeat
			task.wait()
		until humanoid.Parent ~= character
		camera.CameraSubject = humanoid
	end

	if rig then
		rig:Destroy()
	end
	laserMod.Destroy()
	effectController:Destroy()
	effectManager:Destroy()
end)

runService.RenderStepped:Connect(function(dt: number)
	if math.ceil(1 / dt) < 5 then -- Skip the render stepped function if FPS is lower than 5 to avoid stuttering issues
		return
	end

	if not characterState.dead() and character:FindFirstChild("Head") then
		movementController:UpdateRender(dt)
		cameraController:UpdateRender(dt)
		viewmodelController:UpdateRender(dt)
		viewmodelController:UpdateMovementSway(dt, movementController.tempWalkSpeed, characterState.vehicleSeated())
		weaponController:UpdateRender(dt)
		laserMod.UpdateRender(dt)
		replicationController:UpdateRender(dt)
	end
end)

runService.Heartbeat:Connect(function(dt: number)
	movementController:UpdateHeartbeat(dt)
	weaponController:UpdateHeartbeat(dt)
	uiController:UpdateHeartbeat(dt)
	effectController:UpdateHeartbeat(dt)
	viewmodelController:UpdateHeartbeat(dt)
end)

Charm.effect(function()
	if weaponState.equipped() then
		inputController:BindGunInputs()
	else
		inputController:UnbindGunInputs()
	end
end)
