local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Framework = ReplicatedStorage.SPH_Framework
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Charm = require(Packages.Charm)
local Access = require(Framework.Access)
local WeaponStateModule = require(Framework.State.WeaponState)
local config = Access.config
local Camera = workspace.CurrentCamera

local HolosightMod = {}
HolosightMod.__index = HolosightMod

function HolosightMod.new(weaponState: WeaponStateModule.WeaponState)
	local self = setmetatable({
		activeSights = {},
		weaponState = weaponState,
	}, HolosightMod)

	Charm.effect(function()
		return self:SyncActiveSights()
	end)

	return self
end



function HolosightMod:SyncActiveSights()
	self.activeSights = {}
	local gunModel = self.weaponState.gunModel()
	if not gunModel then
		return
	end

	for _, part in ipairs(gunModel:GetDescendants()) do
		if part.Name == "SightReticle" and part:IsA("BasePart") then
			table.insert(self.activeSights, { part = part, ui = nil })
		end
	end

	local conn = gunModel.DescendantAdded:Connect(function(descendant)
		if descendant.Name == "SightReticle" and descendant:IsA("BasePart") then
			table.insert(self.activeSights, { part = descendant, ui = nil })
		end
	end)

	return function()
		print("disconnecting")
		conn:Disconnect()
		conn = nil
	end
end

function HolosightMod:UpdateRender(dt)
	if #self.activeSights == 0 then
		return
	end

	local camPos = Camera.CFrame.Position
	local fovScale = Camera.FieldOfView / config.defaultFOV

	for _, sightData in ipairs(self.activeSights) do
		local sight: BasePart = sightData.part
		local sightUI: GuiObject? = sightData.ui

		if not sightUI then
			local frame = sight:FindFirstChild("SurfaceGui") and sight.SurfaceGui:FindFirstChild("Frame")
			if not frame then
				continue
			end
			sightUI = frame:FindFirstChild("Reticle") or frame:FindFirstChild("Holo")
			if not sightUI then
				continue
			end
			sightData.ui = sightUI
			sightData.isHolo = (sightUI.Name == "Holo")
		end

		local dist = sight.CFrame:PointToObjectSpace(camPos) / sight.Size
		sightUI.Position = UDim2.fromScale(0.5 + dist.X, 0.5 - dist.Y)

		if sightData.isHolo then
			sightUI.Size = UDim2.fromScale(fovScale, fovScale)
		end
	end
end


return HolosightMod
