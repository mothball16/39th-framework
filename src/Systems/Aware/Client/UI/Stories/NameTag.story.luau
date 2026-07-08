local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local create = Vide.create
local UILabs = require("@game/ReplicatedStorage/DevPackages/ui-labs")
local NameTag = require("../Roots/NameTag")

local controls = {
	Health = UILabs.Slider(100, -50, 150),
	MaxHealth = UILabs.Slider(100, -50, 150),
	NameTag = UILabs.String("[R] moth"),
}

local story = UILabs.CreateVideStory({
	controls = controls,
	vide = Vide,
}, function(props)
	return create "Frame" {
		Size = UDim2.fromScale(1, 0.10),
		BackgroundTransparency = 1,
		NameTag({
			health = props.controls.Health,
			maxHealth = props.controls.MaxHealth,
			nameTag = props.controls.NameTag,
			textSize = function()
				return 14
			end,
		}),
	}
end)

return story
