local ReplicatedStorage = game:GetService("ReplicatedStorage")
local sph = require(ReplicatedStorage.SPH_Framework.GameAccess)
local assets = sph.assets
local framework = sph.framework
local bridgeNet = require(framework.Network.BridgeNet)

local repToggleAttachment = bridgeNet.CreateBridge("ReplicateToggleAttachment")
local lasers = {}

local AttachmentReplicationController = {}

local DEFAULT_LASER_COLOR = Color3.fromRGB(255, 100, 100)

local function getLaserColor(laserLike: Instance): Color3
	-- Support legacy "Color" child (Color3Value) but do not require it.
	local colorValue = laserLike:FindFirstChild("Color")
	if colorValue and colorValue:IsA("Color3Value") then
		return colorValue.Value
	end
	return DEFAULT_LASER_COLOR
end

local function resolveLaserPoint(laserLike: Instance?): Attachment?
	if not laserLike or not laserLike.Parent then return nil end
	if laserLike:IsA("Attachment") then
		return laserLike
	end

	local main = laserLike:FindFirstChild("Main")
	if main then
		local underMain = main:FindFirstChild("Laser")
		if underMain and underMain:IsA("Attachment") then
			return underMain
		end
	end

	local direct = laserLike:FindFirstChild("Laser")
	if direct and direct:IsA("Attachment") then
		return direct
	end

	return nil
end

function AttachmentReplicationController.Initialize()
	repToggleAttachment:Connect(AttachmentReplicationController.OnToggleAttachment)
end

function AttachmentReplicationController.OnToggleAttachment(attachment, toggle, character)
	if not attachment then return end
	if attachment.Name == "Flashlight" then
		local light = attachment:FindFirstChildWhichIsA("Light")
		if light then light.Enabled = toggle end
	elseif attachment.Name == "Laser" then
		if toggle then
			local laserDot = Instance.new("Attachment", workspace.Terrain)
			laserDot.Name = "ReplicatedLaser"

			local laserDotUI = assets.HUD.LaserDotUI:Clone()
			laserDotUI.Enabled = true
			laserDotUI.Dot.ImageColor3 = getLaserColor(attachment)
			laserDotUI.Parent = laserDot

			local newLaser = {
				laserDot = laserDot,
				attachment = attachment,
				ignoreModel = character
			}
			table.insert(lasers, newLaser)
		else
			for i, laserObject in ipairs(lasers) do
				if laserObject.attachment == attachment then
					laserObject.laserDot:Destroy()
					table.remove(lasers, i)
					break
				end
			end
		end
	elseif attachment.Name == "Bipod" then
		if attachment.Parent and attachment.Parent.Parent then
			for _, bipObject in ipairs(attachment.Parent.Parent:GetChildren()) do
				if bipObject.Name == "Bipod_On" then
					bipObject.Transparency = toggle and 0 or 1
				elseif bipObject.Name == "Bipod_Off" then
					bipObject.Transparency = toggle and 1 or 0
				end
			end
		end
	end
end

function AttachmentReplicationController.UpdateRender(dt)
	debug.profilebegin("SPH.AttachmentReplication.UpdateRender")
	for i = #lasers, 1, -1 do
		local laserObject = lasers[i]
		local laserPoint = resolveLaserPoint(laserObject.attachment)
		if laserPoint then
			local laserRayParams = RaycastParams.new()
			laserRayParams.FilterType = Enum.RaycastFilterType.Exclude
			if laserObject.ignoreModel then
				laserRayParams.FilterDescendantsInstances = { laserObject.ignoreModel }
			end
			laserRayParams.RespectCanCollide = true
			local laserDotPoint = laserObject.laserDot
			local rayResult = workspace:Raycast(laserPoint.WorldPosition, laserPoint.WorldCFrame.LookVector * 600, laserRayParams)
			if rayResult then
				laserObject.laserDot.LaserDotUI.Enabled = true
				laserDotPoint.WorldPosition = rayResult.Position
			else
				laserObject.laserDot.LaserDotUI.Enabled = false
			end
		else
			if laserObject.laserDot then
				laserObject.laserDot:Destroy()
			end
			table.remove(lasers, i)
		end
	end
	debug.profileend()
end

return AttachmentReplicationController