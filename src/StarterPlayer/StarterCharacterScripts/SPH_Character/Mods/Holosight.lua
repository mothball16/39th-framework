local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Charm = require(Packages.Charm)

local assets = ReplicatedStorage:WaitForChild("SPH_Assets")
local config = require(assets.GameConfig)

local State = require(script.Parent.Parent.Controllers.CharacterState)
local WeaponState = require(script.Parent.Parent.Controllers.WeaponState)

local Camera = workspace.CurrentCamera
local HolosightMod = {}
local activeSights = {}
local gunModelConnection = nil


local invDefaultFOV = 1 / config.defaultFOV

function HolosightMod.Initialize(params)
	Charm.subscribe(WeaponState.gunModel, HolosightMod.OnGunModelChanged)
end

function HolosightMod.OnGunModelChanged(gunModel)
	if gunModelConnection then
		gunModelConnection:Disconnect()
		gunModelConnection = nil
	end
	activeSights = {}

	if not gunModel then
		return
	end

	for _, part in ipairs(gunModel:GetDescendants()) do
		if part.Name == "SightReticle" and part:IsA("BasePart") then
			table.insert(activeSights, {part = part, ui = nil})
		end
	end

	gunModelConnection = gunModel.DescendantAdded:Connect(function(descendant)
		if descendant.Name == "SightReticle" and descendant:IsA("BasePart") then
			table.insert(activeSights, {part = descendant, ui = nil})
		end
	end)
end

function HolosightMod.UpdateRender(dt)
	if #activeSights == 0 then return end

	local camPos = Camera.CFrame.Position
	local fovScale = Camera.FieldOfView * invDefaultFOV

	for _, sightData in ipairs(activeSights) do
		local sight: BasePart = sightData.part
		local sightUI: GuiObject? = sightData.ui

		if not sightUI then
			local frame = sight:FindFirstChild("SurfaceGui") and sight.SurfaceGui:FindFirstChild("Frame")
			if not frame then continue end
			sightUI = frame:FindFirstChild("Reticle") or frame:FindFirstChild("Holo")
			if not sightUI then continue end
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