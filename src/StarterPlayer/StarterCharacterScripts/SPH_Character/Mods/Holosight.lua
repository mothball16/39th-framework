local ReplicatedStorage = game:GetService("ReplicatedStorage")
local assets = ReplicatedStorage:WaitForChild("SPH_Assets")
local config = require(assets.GameConfig)

local Camera = workspace.CurrentCamera
local WeaponController

local HolosightMod = {}

function HolosightMod.Initialize(params)
	WeaponController = params.Controllers.WeaponController
end

function HolosightMod.UpdateRender(dt)
	if not WeaponController.sights then return end
	for _, sight:BasePart in ipairs(WeaponController.sights) do
		local frame = sight:FindFirstChild("SurfaceGui") and sight.SurfaceGui:FindFirstChild("Frame")
		if not frame then continue end
		local sightUI = frame:FindFirstChild("Reticle") or frame:FindFirstChild("Holo")
		if not sightUI then continue end

		local dist = sight.CFrame:PointToObjectSpace(Camera.CFrame.Position) / sight.Size
		sightUI.Position = UDim2.fromScale(0.5 + dist.X, 0.5 - dist.Y)

		if sightUI.Name == "Holo" then
			local newSize = Camera.FieldOfView / config.defaultFOV
			sightUI.Size = UDim2.fromScale(newSize, newSize)
		end
	end
end

return HolosightMod