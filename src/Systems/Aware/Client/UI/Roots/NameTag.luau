local Vide = require("@game/ReplicatedStorage/Packages/Vide")

local source = Vide.source
local create = Vide.create
local derive = Vide.derive

local Types = require("@game/ReplicatedStorage/Systems/Aware/Core/Types")

return function(props: {
	health: () -> number,
	maxHealth: () -> number,
	playerKey: () -> string,
	shortenName: Types.ShortenName,
})
	local percent = derive(function()
		return props.health() / props.maxHealth()
	end)
	local name = derive(function()
		return `{props.shortenName(props.playerKey())} [{math.round(percent() * 100)}%]`
	end)
	return create "Frame" {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundTransparency = 1,
		create "TextLabel" {
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.new(0, 0, 0, 0),
			BackgroundTransparency = 1,
			Text = name,
			TextColor3 = Color3.new(1, 1, 1),
			TextStrokeTransparency = 0.5,
			TextScaled = true,
			FontFace = Font.fromEnum(Enum.Font.RobotoMono),
		},
	}
end
