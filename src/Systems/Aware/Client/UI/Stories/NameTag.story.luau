local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local create = Vide.create
local source = Vide.source
local UILabs = require("@game/ReplicatedStorage/DevPackages/ui-labs")
local ShortenName = require("../Logic/ShortenName")
local NameTag = require("../Roots/NameTag")

local controls = {
	Health = UILabs.Slider(100, -50, 150),
	MaxHealth = UILabs.Slider(100, -50, 150),
	PlayerKey = UILabs.String("88451868"),
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
			playerKey = props.controls.PlayerKey,
			shortenName = ShortenName,
		}),
	}
end)

return story
