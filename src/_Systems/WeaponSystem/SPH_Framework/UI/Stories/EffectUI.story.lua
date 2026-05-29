
local UILabs = require("@game/ReplicatedStorage/DevPackages/ui-labs")
local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local create = Vide.create
local HitmarkerTypes = require("../Configs/HitmarkerTypes")
local EffectManager = require("../Logic/EffectManager")
local EffectUI = require("../Roots/EffectUI")
local StoryButtonList = require("../Components/StoryButtonList")

local typeChoices = {}
for k in HitmarkerTypes do
	table.insert(typeChoices, k)
end

local controls = {
	Type = UILabs.Choose(typeChoices, 1),
}




local story = UILabs.CreateVideStory({
	vide = Vide,
	controls = controls,
}, function(props)
	local suppressionFactor = Vide.source(0)
	local effectManager = EffectManager.new(suppressionFactor, 0.2)

	Vide.cleanup(function()
		effectManager:Destroy()
	end)

	local storyActions = {
		{
			text = "Add Hitmarker",
			onActivated = function()
				effectManager:PushHitmarker(HitmarkerTypes[props.controls.Type()]())
			end,
		},
		{
			text = "Add Damage (+25)",
			onActivated = function()
				effectManager:PushDamage(25)
			end,
		},
		{
			text = "Suppression +0.25",
			onActivated = function()
				suppressionFactor(math.clamp(suppressionFactor() + 0.25, 0, 1))
			end,
		},
		{
			text = "Suppression 0",
			onActivated = function()
				suppressionFactor(0)
			end,
		},
	}

	return create "Frame" {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),

		EffectUI({
			activeDamage = effectManager.activeDamage,
			activeHitmarkers = effectManager.activeHitmarkers,
			suppressionFactor = suppressionFactor,
			panelPosition = Vide.source(UDim2.fromScale(0.53, 0.55)),
			suppressionLimit = 1,
		}),

		StoryButtonList({
			actions = storyActions,
		}),
	}
end)

return story
