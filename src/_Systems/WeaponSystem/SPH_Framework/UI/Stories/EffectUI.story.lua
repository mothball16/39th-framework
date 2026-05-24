
local UILabs = require("@game/ReplicatedStorage/DevPackages/ui-labs")
local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local create = Vide.create
local HitmarkerTypes = require("../Configs/HitmarkerTypes")
local EffectManager = require("../Logic/EffectManager")
local EffectUI = require("../Roots/EffectUI")

local typeChoices = {}
for k, v in HitmarkerTypes do
	table.insert(typeChoices, k)
end

local controls = {
	Type = UILabs.Choose(typeChoices, 1),
}

local story = UILabs.CreateVideStory({
	vide = Vide,
	controls = controls,
}, function(props)
	local effectManager = EffectManager.new()

	Vide.cleanup(function()
		effectManager:Destroy()
		warn("unmounted")
	end)

	return create "Frame" {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),


		EffectUI({
			activeHitmarkers = effectManager.activeHitmarkers,
			suppressionFactor = effectManager.suppressionFactor,
		}),

		create "TextButton" {
			Position = UDim2.fromScale(0, 0.95),
			Size = UDim2.fromScale(0.1, 0.05),
			BackgroundTransparency = 1,
			Text = "Add Hitmarker",
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			Activated = function()
				effectManager:PushHitmarker(HitmarkerTypes[props.controls.Type()]())
			end,
		}
	}
end)

return story