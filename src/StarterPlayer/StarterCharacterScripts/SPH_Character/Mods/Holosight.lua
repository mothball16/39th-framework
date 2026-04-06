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
local renderConnection = nil
local gunModelConnection = nil
local activeSights = {}

function HolosightMod.Initialize(params)
	Charm.subscribe(State.equippedTool, HolosightMod.OnEquippedToolChanged)
end

function HolosightMod.OnEquippedToolChanged(tool)
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
	if gunModelConnection then
		gunModelConnection:Disconnect()
		gunModelConnection = nil
	end
	
	activeSights = {}

	if tool then
		task.defer(function()
			if State.equippedTool() ~= tool then return end
			
			local gunModel = WeaponState.gunModel
			if gunModel then
				for _, part in ipairs(gunModel:GetDescendants()) do
					if part.Name == "SightReticle" and part:IsA("BasePart") then
						table.insert(activeSights, part)
					end
				end
				
				gunModelConnection = gunModel.DescendantAdded:Connect(function(descendant)
					if descendant.Name == "SightReticle" and descendant:IsA("BasePart") then
						table.insert(activeSights, descendant)
					end
				end)
			end
			
			renderConnection = RunService.RenderStepped:Connect(HolosightMod.OnRenderStep)
		end)
	end
end

function HolosightMod.UpdateRender(dt)
	for _, sight:BasePart in ipairs(activeSights) do
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