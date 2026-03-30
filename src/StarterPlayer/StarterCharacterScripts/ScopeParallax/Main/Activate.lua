local Activate = {}

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local StarterCharacterScripts = StarterPlayer:WaitForChild("StarterCharacterScripts")

local camera = workspace.CurrentCamera

-- constants
-- adjusted for texture size
local DEFAULT_OCU_SCALE = 3.75
local DEFAULT_OBJ_SCALE = 3.45

-- globals
local settings = nil
local currentGun = nil
local scopeConnect = nil

-- referencing objects with tables has faster runtime
local scopeFocus = {}
local focusTexture = {}
local projectedSights = {}

local ocuScale = DEFAULT_OCU_SCALE
local objScale = DEFAULT_OBJ_SCALE

local eyeReliefDistance = 0

local glassPart = nil
local model

local function getSurfaceCFrame(part)
	local cframe = part.CFrame
	local offset = CFrame.new(-Vector3.zAxis * part.Size.Z * 0.5)
	return cframe:ToWorldSpace(offset)
end

local function updateFocus()
	local scopeFocus = scopeFocus[1]
	
	if currentGun.Parent == nil or not scopeFocus then
		scopeConnect:Disconnect()
		return
	end
	
	local aimpartOffset = currentGun.AimPart.CFrame:ToObjectSpace(scopeFocus.CFrame)
	-- auto eye relief
	local adjustedOffset = CFrame.new(aimpartOffset.Position.X, -aimpartOffset.Position.Y, 0) -- we only want the uv values
	
	local objLensCFrame = scopeFocus.CFrame * CFrame.new(-scopeFocus.Size.X/2,0,0) * CFrame.Angles(0, -math.pi/2, 0)
	local ocuLensCFrame =  scopeFocus.CFrame * CFrame.new(scopeFocus.Size.X/2,0,0) * CFrame.Angles(0, -math.pi/2, 0) * adjustedOffset

	local ocuLensOffset = camera.CFrame:ToObjectSpace(ocuLensCFrame)
	local objLensOffset = objLensCFrame:ToObjectSpace(camera.CFrame)
	
	local objRecip = 1/eyeReliefDistance*objScale
	local ocuRecip = 1/eyeReliefDistance*ocuScale

	-- ocular
	local ocuRelief = eyeReliefDistance * 2 + ocuLensOffset.Position.Z
	local ocuSize = scopeFocus.Size.Y * ocuRelief * ocuRecip
	local ocuOffset = (scopeFocus.Size.Y * 0.5) * (ocuRelief * ocuRecip - 1)

	local ocuHoz = math.tan(-ocuLensOffset.Position.X * settings.focusSensitivity) / settings.eyeboxCurve
	local ocuVert = math.tan(ocuLensOffset.Position.Y * settings.focusSensitivity) / settings.eyeboxCurve

	local ocuU = ocuHoz + ocuOffset
	local ocuV = ocuVert + ocuOffset
	-- objective
	local objRelief = -ocuLensOffset.Position.Z
	local objSize = scopeFocus.Size.Y * objRelief * objRecip
	local objOffset = scopeFocus.Size.Y * 0.5 * (objRelief * objRecip - 1) 

	local objHoz = objLensOffset.Position.X
	local objVert = objLensOffset.Position.Y

	local objU = objOffset + objHoz
	local objV = objOffset + objVert

	local dist = -math.abs(ocuHoz + ocuVert)
	local lensFocus = -math.abs(eyeReliefDistance-objRelief)

	-- ocular lens
	focusTexture[1].OffsetStudsU = ocuU
	focusTexture[1].OffsetStudsV = ocuV
	focusTexture[1].StudsPerTileU = ocuSize
	focusTexture[1].StudsPerTileV = ocuSize
	-- objective lens
	focusTexture[2].OffsetStudsU = objU
	focusTexture[2].OffsetStudsV = objV
	focusTexture[2].StudsPerTileU = objSize
	focusTexture[2].StudsPerTileV = objSize
	-- light
	focusTexture[3].Transparency = 1 + (dist) * settings.lightSensitivity + settings.lightDeadzone
	-- ocular chromatic aberration
	focusTexture[4].OffsetStudsU = ocuU
	focusTexture[4].OffsetStudsV = ocuV
	focusTexture[4].StudsPerTileU = ocuSize
	focusTexture[4].StudsPerTileV = ocuSize
	focusTexture[4].Transparency = math.max(0, 1 + dist * settings.ocularCASensitivity + lensFocus + settings.ocularCADeadzone)
	-- objective chromatic aberration
	focusTexture[5].OffsetStudsU = objU
	focusTexture[5].OffsetStudsV = objV
	focusTexture[5].StudsPerTileU = objSize
	focusTexture[5].StudsPerTileV = objSize
	focusTexture[5].Transparency = 1 + dist * settings.objectiveCASensitivity + lensFocus + settings.objectiveCADeadzone

	if glassPart then
		glassPart.CFrame = scopeFocus.CFrame * CFrame.new(scopeFocus.Size.X/2 - settings.glassOffset, 0, 0)
		
		local maxDist = scopeFocus.Size.Y
		local ocuX = -ocuLensOffset.Position.X
		local ocuY = ocuLensOffset.Position.Y

		if math.abs(ocuX) > maxDist or math.abs(ocuY) > maxDist then
			-- probably not aiming
			glassPart.Transparency = 1
		else
			glassPart.Transparency = settings.glassTransparency
		end
	end
end

function Activate.start(model: Model, Patcher: {})
	-- clear old values
	scopeFocus = {}
	focusTexture = {}
	projectedSights = {}
	ocuScale = DEFAULT_OCU_SCALE
	objScale = DEFAULT_OBJ_SCALE
	currentGun = model
	
	local aimpartPosition = (currentGun.AimPart.CFrame * CFrame.new(0, 0, Patcher.aimpartZOffset)).Position
	local cleanup = {}

	for _, part in currentGun:GetDescendants() do -- DD_SPH: Replaced GetChildren with GetDescendants to account for gunsmith attachments
		if part.Name == "SCOPE_FOCUS" then
			settings = require(part:FindFirstChildWhichIsA("ModuleScript"))

			-- asign table values & setup textures
			scopeFocus[1] = part
			focusTexture[1] = part.OcularLens
			focusTexture[2] = part.ObjectiveLens
			focusTexture[3] = part.Light
			focusTexture[4] = part.OcularCA
			focusTexture[5] = part.ObjectiveCA

			focusTexture[1].Transparency = 0
			focusTexture[2].Transparency = 0
			part.Transparency = 1

			ocuScale += settings.eyeReliefOffset
			objScale -= settings.eyeReliefOffset

			ocuScale *= settings.ocularLensScale
			objScale *= settings.objectiveLensScale
			
			-- offset of eye end of scope
			local offsetPosition = (part.CFrame * CFrame.new(part.Size.X/2,0,0)).Position
			eyeReliefDistance = (aimpartPosition - offsetPosition).Magnitude
			
			Patcher.parentingMethod(part)
			-- setup glass
			if settings.useGlassEffect then
				glassPart = Instance.new("Part")
				local mesh = Instance.new("SpecialMesh", glassPart)

				glassPart.CFrame = part.CFrame * CFrame.new(part.Size.X/2 - settings.glassOffset, 0, 0)
				glassPart.Material = Enum.Material.Glass
				glassPart.Color = settings.glassColor
				glassPart.Transparency = settings.glassTransparency
				glassPart.CanCollide = false

				mesh.MeshType = Enum.MeshType.Sphere

				local scopePos = (part.CFrame * CFrame.new(part.Size.X/2, 0, 0)).Position

				local partDistance = (aimpartPosition - scopePos).Magnitude
				local glassDistance = (aimpartPosition - glassPart.Position).Magnitude

				local glassSize = part.Size.Z * (glassDistance/partDistance)
				local dist = (glassPart.Position - scopePos).Magnitude

				glassPart.Size = Vector3.new(settings.glassZoomFactor*(1+dist^2), glassSize, glassSize)
				glassPart.Parent = currentGun
			end

			-- PreRender will work when acs main loop is .RenderStepped or :BindToRenderStep
			scopeConnect = RunService.PreRender:Connect(updateFocus)

			table.insert(cleanup, part)
		end
	end

	return cleanup
end

return Activate