
local RunService = game:GetService("RunService")
local UILabs = require("@game/ReplicatedStorage/DevPackages/ui-labs")
local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local create, source = Vide.create, Vide.source
local Hitmarker = require("../Components/Hitmarker")
local HitmarkerTypes = require("../Configs/HitmarkerTypes")

local hitmarkers: () -> {Hitmarker.HitmarkerProps} = source({})

local typeChoices = {}
for k, v in HitmarkerTypes do
	table.insert(typeChoices, k)
end

local controls = {
	Speed = UILabs.Slider(1, 0, 10, 0.25),
	Type = UILabs.Choose(typeChoices, 1),
}

local function spawnHitmarker(kind: string)
	local hitmarker = HitmarkerTypes[kind]()
	hitmarker.TimeElapsed = Vide.source(0)
	return hitmarker
end

local story = UILabs.CreateVideStory({
	vide = Vide,
	controls = controls,
}, function(props)
	local connection: RBXScriptConnection?
	local function play()
		if connection then
			return
		end
		connection = RunService.RenderStepped:Connect(function(dt)
			local state = hitmarkers()
			local indexesDirty = false
			for i, v in state do
				v.TimeElapsed(v.TimeElapsed() + dt * props.controls.Speed())
				if v.TimeElapsed() >= v.lifetime then
					state[i] = nil
					indexesDirty = true
				end
			end
			if indexesDirty then
				hitmarkers(state)
			end
		end)
	end

	local function pause()
		if connection then
			connection:Disconnect()
			connection = nil
		end
	end
	play()
	Vide.cleanup(function()
		pause()
		warn("unmounted")
	end)


	return create "Frame" {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),

		Vide.indexes(hitmarkers, function(item, index)
			return Hitmarker(item())
		end),
		
		create "TextButton" {
			Position = UDim2.fromScale(0.05, 0.95),
			Size = UDim2.fromScale(0.1, 0.05),
			BackgroundTransparency = 1,
			Text = "Play",
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			Activated = play,
		},

		create "TextButton" {
			Position = UDim2.fromScale(0.15, 0.95),
			Size = UDim2.fromScale(0.1, 0.05),
			BackgroundTransparency = 1,
			Text = "Pause",
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			Activated = pause,
		},

		create "TextButton" {
			Position = UDim2.fromScale(0.25, 0.95),
			Size = UDim2.fromScale(0.1, 0.05),
			BackgroundTransparency = 1,
			Text = "Add Hitmarker",
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			Activated = function()
				table.insert(hitmarkers(), spawnHitmarker(props.controls.Type()))
				hitmarkers(hitmarkers())
			end,
		}
	}
end)

return story