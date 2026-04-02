local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Charm = require(Packages.Charm)
local TweenService = game:GetService("TweenService")

local assets = ReplicatedStorage:WaitForChild("SPH_Assets")
local config = require(assets.GameConfig)
local State = require(script.Parent.CharacterState)

local CameraController = {
	camera = nil,
	character = nil,
	humanoid = nil,
	humanoidRootPart = nil,
	rootJoint = nil,
	rigType = nil,
	
	cameraRollAngle = 0,
	cameraLeanRotation = 0,
	cameraOffsetTarget = Vector3.zero,
	
	MovementController = nil,
}

local function LerpNumber(number, target, speed)
	return number + (target - number) * speed
end

function CameraController.Initialize(params)
	CameraController.camera = params.camera
	CameraController.character = params.character
	CameraController.humanoid = params.humanoid
	CameraController.humanoidRootPart = params.humanoidRootPart
	CameraController.rootJoint = params.rootJoint
	CameraController.rigType = params.rigType
	
	CameraController.MovementController = params.MovementController
	
	Charm.subscribe(State.sprinting, CameraController.OnSprintChanged)
end


function CameraController.OnSprintChanged(sprinting)
	--[[
	if sprinting then
		if depthOfField then
			CameraController.ChangeDoF(0, 6, 0, 0.3)
		end
	end]]
end

function CameraController.OnFreelookIntent(inputState, inputObject)
	local inputBegan = Enum.UserInputState.Begin
	if inputState == inputBegan then -- Holding
		State.freeLook(true)
		CameraController.humanoid.AutoRotate = false
		State.freeLookRotation(CameraController.camera.CFrame - CameraController.camera.CFrame.Position)
	else -- Stopped holding
		State.freeLook(false)
		local freeLookOffset = State.freeLookRotation():ToObjectSpace(CameraController.camera.CFrame)
		State.freeLookOffset(freeLookOffset - freeLookOffset.Position)
		CameraController.humanoid.AutoRotate = true
	end
end


function CameraController.UpdateRender(dt)
	local camera = CameraController.camera
	local humanoid = CameraController.humanoid
	local humanoidRootPart = CameraController.humanoidRootPart
	local rootJoint = CameraController.rootJoint
	local rigType = CameraController.rigType
	local MovementController = CameraController.MovementController
	
	-- Limit camera rotation
	if (humanoid.Sit and not MovementController.vehicleSeated and State.firstPerson() or State.freeLook()) and config.cameraLimitInSeats then
		local cameraCFrame = humanoidRootPart.CFrame:ToObjectSpace(camera.CFrame)
		local x, y, z = cameraCFrame:ToOrientation()
		local a = camera.CFrame.Position.X
		local b = camera.CFrame.Position.Y
		local c = camera.CFrame.Position.Z

		local xlimit = math.rad(math.clamp(math.deg(x), -60, 60))
		local ylimit = math.rad(math.clamp(math.deg(y), -60, 60))
		local zlimit = math.rad(math.clamp(math.deg(z), -60, 60))
		local limitedCFrame = humanoidRootPart.CFrame:ToWorldSpace(CFrame.new(a, b, c) * CFrame.fromOrientation(xlimit, ylimit, zlimit))
		camera.CFrame = CFrame.new(camera.CFrame.Position) * (limitedCFrame - limitedCFrame.Position)
	end

	local xOffset
	local yOffset
	local zOffset

	if rigType == Enum.HumanoidRigType.R6 then -- DD_SPH: Added rig-check to correct positioning
		if config.firstPersonBody and State.firstPerson() then
			local xHead = humanoidRootPart.CFrame:ToObjectSpace(camera.CFrame):ToEulerAngles()
			local rotationOffset = -1.2 + (xHead + 1.4) / 2.8
			CameraController.cameraOffsetTarget = Vector3.new(0, 0, rotationOffset)
		else
			CameraController.cameraOffsetTarget = Vector3.zero
		end

		xOffset = 0
		yOffset = 0
		zOffset = CameraController.cameraOffsetTarget.Z

		if State.stance() == 1 then
			yOffset = -1
			if State.firstPerson() then zOffset -= 0.3 end
		elseif State.stance() == 2 then
			yOffset = -1.5
			if State.firstPerson() then zOffset = -1.7 end
		end

		-- Lean offset
		if State.lean() < 0 then
			xOffset = -1
			yOffset += -0.2
		elseif State.lean() > 0 then
			xOffset = 1
			yOffset += -0.2
		end
	else
		if config.firstPersonBody and State.firstPerson() then
			local xHead = humanoidRootPart.CFrame:ToObjectSpace(camera.CFrame):ToEulerAngles()
			local rotationOffset = -1.6 + (xHead + 1.4) / 2.8
			CameraController.cameraOffsetTarget = Vector3.new(0, 0, rotationOffset)
		else
			CameraController.cameraOffsetTarget = Vector3.zero
		end

		xOffset = 0
		yOffset = 0
		zOffset = CameraController.cameraOffsetTarget.Z

		if State.stance() == 1 then -- DD_SPH: Adjusted camera positioning to reflect R15.
			yOffset = .5
			if State.firstPerson() then zOffset -= 1.5 end --rev
		elseif State.stance() == 2 then
			yOffset = 1.5
			if State.firstPerson() then zOffset = -3 end --rev
		end

		-- Lean offset
		if State.lean() < 0 then
			xOffset = -1
			yOffset -= 0.2 --rev
		elseif State.lean() > 0 then
			xOffset = 1
			yOffset -= 0.2 --rev
		end
	end --</DD_SPH>

	if not MovementController.vehicleSeated and camera.CameraType == Enum.CameraType.Custom then
		-- Update camera offset
		if rigType == Enum.HumanoidRigType.R6 then -- DD_SPH: Different offsets for different rigs
			CameraController.cameraOffsetTarget = Vector3.new(xOffset, yOffset, zOffset)
		else
			CameraController.cameraOffsetTarget = Vector3.new(xOffset, -yOffset, zOffset)
		end
		humanoid.CameraOffset = humanoid.CameraOffset:Lerp(CameraController.cameraOffsetTarget, 0.1 * dt * 60)

		-- </DD_SPH>
		CameraController.cameraLeanRotation = LerpNumber(CameraController.cameraLeanRotation, 15 * -State.lean(), 0.1)
		camera.CFrame *= CFrame.Angles(0, 0, math.rad(CameraController.cameraLeanRotation))

		-- Camera tilt
		if config.cameraTilting and State.firstPerson() then
			local maxTiltAngle = 2
			local relativeVelocity = humanoidRootPart.CFrame:VectorToObjectSpace(humanoidRootPart.Velocity)
			local mouseDelta = UserInputService:GetMouseDelta()
			local targetRollAngle = math.clamp(-relativeVelocity.X, -maxTiltAngle, maxTiltAngle) + mouseDelta.X / 2
			CameraController.cameraRollAngle = LerpNumber(CameraController.cameraRollAngle, targetRollAngle, 0.07 * dt * 60)
			camera.CFrame *= CFrame.Angles(0, 0, math.rad(CameraController.cameraRollAngle))
		end
	end
end

function CameraController.UpdateFOV(dt)
	local camera = CameraController.camera
	local camSensFactor = camera.FieldOfView / config.defaultFOV
	if State.aiming() then
		camera.FieldOfView = LerpNumber(camera.FieldOfView, State.aimFOVTarget(), 0.3 * (dt * 60))
		UserInputService.MouseDeltaSensitivity = State.aimSens() * camSensFactor
	else
		UserInputService.MouseDeltaSensitivity = 1 * camSensFactor
	end
end


-- TODO: REFACTOR
local depthOfField = game.Lighting:FindFirstChild("SPH_DoF")
if not depthOfField and config.blurEffects then
	depthOfField = Instance.new("DepthOfFieldEffect",game.Lighting)
end
if depthOfField then depthOfField.Name = "SPH_DoF" end

function CameraController.ChangeDoF(fInt,fDist,fRad,nInt)
	if not depthOfField then return end
	TweenService:Create(depthOfField,TweenInfo.new(0.2),{
		FarIntensity = fInt,
		FocusDistance = fDist,
		InFocusRadius = fRad,
		NearIntensity = nInt
	}):Play()
end

return CameraController