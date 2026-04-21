local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Charm = require(Packages.Charm)

local sph = require(ReplicatedStorage.SPH_Framework.Core.GameAccess)
local assets = sph.assets
local modules = sph.framework
local Enums = require(modules.Core.Enums)
local config = sph.config
local bridgeNet = require(modules.Network.BridgeNet)
local weaponPrefsClient = require(modules.Weapons.WeaponPrefsClient)

local Intents = Enums.Intents
local CharacterStateModule = require(ReplicatedStorage.SPH_Framework.State.CharacterState)
local WeaponStateModule = require(ReplicatedStorage.SPH_Framework.State.WeaponState)
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local LaserMod = {
	laserDotGui = nil,
	laserDotImage = nil,
	laserDotPoint = nil,
	laserBeamFP = nil,
	laserBeamTP = nil,
	WeaponController = nil,
}

local weaponState: WeaponStateModule.WeaponState
local State: CharacterStateModule.CharacterState


local MAX_DIST = 800
local MIN_ALPHA = 0.2
local MAX_ALPHA = 0
local MIN_DOT_SIZE = 4
local MAX_DOT_SIZE = 16
local DOT_SIZE_LERP_EXPONENT = 0.3

LaserMod.playerToggleAttachment = bridgeNet.CreateBridge("PlayerToggleAttachment")

local function getLaserAttachment(model)
	if not model then return nil end

	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("Model") and child:FindFirstChild("Main") then
			local laser = child.Main:FindFirstChild("Laser")
			if laser then
				return laser
			end
		end
	end

	local grip = model:FindFirstChild("Grip")
	if grip then
		return grip:FindFirstChild("Laser")
	end

	return nil
end

function LaserMod.GetThirdPersonGunModel()
	if not LaserMod.WeaponController then return nil end
	if not LaserMod.WeaponController.GetThirdPersonGunModel then return nil end
	return LaserMod.WeaponController.GetThirdPersonGunModel()
end

function LaserMod.GetLaserPoint()
	if State.firstPerson() then
		return getLaserAttachment(weaponState.gunModel())
	end
	return getLaserAttachment(LaserMod.GetThirdPersonGunModel())
end

function LaserMod.UpdateAttachmentsVisibility()
	if not LaserMod.laserBeamFP or not LaserMod.laserBeamTP then return end
	if not State.equippedTool() then
		LaserMod.laserBeamFP.Enabled = false
		LaserMod.laserBeamTP.Enabled = false
		return
	end

	local laserOn = weaponState.laserEnabled()
	local isFirstPerson = State.firstPerson()

	if laserOn and config.laserTrail then
		LaserMod.laserBeamFP.Enabled = isFirstPerson
		LaserMod.laserBeamTP.Enabled = not isFirstPerson
		LaserMod.laserBeamFP.Attachment0 = getLaserAttachment(weaponState.gunModel())
		LaserMod.laserBeamTP.Attachment0 = getLaserAttachment(LaserMod.GetThirdPersonGunModel())
	else
		LaserMod.laserBeamFP.Enabled = false
		LaserMod.laserBeamTP.Enabled = false
	end
end

function LaserMod.OnLaserToggled(enabled)
	if not LaserMod.laserDotGui or not LaserMod.laserDotImage then return end
	if not State.equippedTool() then
		LaserMod.laserDotGui.Enabled = false
		LaserMod.UpdateAttachmentsVisibility()
		return
	end

	local applying = weaponPrefsClient.isApplying
	if LaserMod.WeaponController and LaserMod.WeaponController.PlayRepSound and not applying then
		LaserMod.WeaponController.PlayRepSound("Button")
	end
	if not applying then
		LaserMod.playerToggleAttachment:Fire(1, enabled)
	end
	LaserMod.laserDotGui.Enabled = enabled

	if enabled then
		local lazerbeem = getLaserAttachment(weaponState.gunModel())
		if lazerbeem then
			local laserColor = lazerbeem:FindFirstChild("Color") and lazerbeem.Color.Value or Color3.fromRGB(255, 100, 100)
			LaserMod.laserDotImage.ImageColor3 = laserColor
			if config.laserTrail then
				LaserMod.laserBeamFP.Color = ColorSequence.new(laserColor)
				LaserMod.laserBeamTP.Color = ColorSequence.new(laserColor)
			end
		end
	end

	LaserMod.UpdateAttachmentsVisibility()
end

function LaserMod.OnToggleLaserIntent(inputState, inputObject)
	local inputBegan = Enum.UserInputState.Begin
	if inputState == inputBegan then
		if getLaserAttachment(weaponState.gunModel()) then
			weaponState.laserEnabled(not weaponState.laserEnabled())
		end
	end
end

function LaserMod.Initialize(params)
	weaponState = params.weaponState
	State = params.state
	local controllers = params.Controllers or {}
	local InputController = controllers.InputController
	LaserMod.WeaponController = controllers.WeaponController

	LaserMod.laserDotPoint = Instance.new("Attachment")
	LaserMod.laserDotPoint.Parent = workspace.Terrain

	LaserMod.laserDotGui = Instance.new("ScreenGui")
	LaserMod.laserDotGui.Name = "LaserDotScreenGui"
	LaserMod.laserDotGui.IgnoreGuiInset = true
	LaserMod.laserDotGui.ResetOnSpawn = false
	LaserMod.laserDotGui.Enabled = false
	LaserMod.laserDotGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

	local sourceLaserUI = assets.HUD.LaserDotUI
	local sourceDot = sourceLaserUI:FindFirstChild("Dot")
	if sourceDot and sourceDot:IsA("ImageLabel") then
		LaserMod.laserDotImage = sourceDot:Clone()
	else
		LaserMod.laserDotImage = Instance.new("ImageLabel")
		LaserMod.laserDotImage.Size = UDim2.fromOffset(8, 8)
		LaserMod.laserDotImage.BackgroundTransparency = 1
	end
	LaserMod.laserDotImage.Name = "Dot"
	LaserMod.laserDotImage.AnchorPoint = Vector2.new(0.5, 0.5)
	LaserMod.laserDotImage.Position = UDim2.fromOffset(0, 0)
	LaserMod.laserDotImage.Parent = LaserMod.laserDotGui

	LaserMod.laserBeamFP = Instance.new("Beam")
	LaserMod.laserBeamFP.Attachment1 = LaserMod.laserDotPoint
	LaserMod.laserBeamFP.LightInfluence = 0
	LaserMod.laserBeamFP.Brightness = 3
	LaserMod.laserBeamFP.Segments = 1
	LaserMod.laserBeamFP.Width0 = 0.02
	LaserMod.laserBeamFP.Width1 = 0.02
	LaserMod.laserBeamFP.FaceCamera = true
	LaserMod.laserBeamFP.Transparency = NumberSequence.new(0.5)
	LaserMod.laserBeamFP.Name = "FirstPersonLaser"
	LaserMod.laserBeamFP.Parent = LaserMod.laserDotPoint
	LaserMod.laserBeamFP.Enabled = false

	LaserMod.laserBeamTP = LaserMod.laserBeamFP:Clone()
	LaserMod.laserBeamTP.Name = "ThirdPersonLaser"
	LaserMod.laserBeamTP.Parent = LaserMod.laserDotPoint
	LaserMod.laserBeamTP.Enabled = false

	Charm.subscribe(weaponState.laserEnabled, LaserMod.OnLaserToggled)
	Charm.subscribe(State.firstPerson, LaserMod.UpdateAttachmentsVisibility)
	Charm.subscribe(weaponState.gunModel, function(gunModel)
		if not gunModel then
			LaserMod.laserDotGui.Enabled = false
			LaserMod.UpdateAttachmentsVisibility()
		end
	end)

	if InputController and InputController.SetIntentCallback then
		InputController.SetIntentCallback(Intents.TOGGLE_LASER, LaserMod.OnToggleLaserIntent)
	end
end

local function numLerp(a, b, t)
	return a + (b - a) * t
end

function LaserMod.UpdateRender(dt)
	if not weaponState.laserEnabled() then return end
	if not LaserMod.laserDotPoint then return end

	local laserPoint = LaserMod.GetLaserPoint()
	if not laserPoint then return end

	local laserRayParams = RaycastParams.new()
	laserRayParams.FilterType = Enum.RaycastFilterType.Exclude
	laserRayParams.FilterDescendantsInstances = {weaponState.gunModel(), State.Parts.Character}
	laserRayParams.RespectCanCollide = true
	local dist
	local rayResult = workspace:Raycast(laserPoint.WorldPosition, laserPoint.WorldCFrame.LookVector * MAX_DIST, laserRayParams)
	if rayResult then
		LaserMod.laserDotPoint.WorldPosition = rayResult.Position
		dist = (rayResult.Position - State.Parts.HRP.Position).Magnitude
	else
		LaserMod.laserDotPoint.WorldPosition = laserPoint.WorldCFrame.Position + laserPoint.WorldCFrame.LookVector * MAX_DIST
		dist = MAX_DIST
	end

	local screenPoint, isVisible = Camera:WorldToViewportPoint(LaserMod.laserDotPoint.WorldPosition)
	local dotVisible = isVisible and screenPoint.Z > 0 and LaserMod.laserDotGui.Enabled
	LaserMod.laserDotImage.Visible = dotVisible
	if dotVisible then
		local normalizedDist = math.clamp(dist / MAX_DIST, 0, 1)
		LaserMod.laserDotImage.Position = UDim2.fromOffset(screenPoint.X, screenPoint.Y)
		LaserMod.laserDotImage.ImageTransparency = numLerp(MAX_ALPHA, MIN_ALPHA, normalizedDist)
		local dotSize = numLerp(MAX_DOT_SIZE, MIN_DOT_SIZE, normalizedDist ^ DOT_SIZE_LERP_EXPONENT)
		LaserMod.laserDotImage.Size = UDim2.fromOffset(dotSize, dotSize)
	end
end

return LaserMod
