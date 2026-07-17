local Vide = require("@game/ReplicatedStorage/Packages/Vide")

local create = Vide.create
local derive = Vide.derive

local Types = require("@game/ReplicatedStorage/Systems/Aware/Core/Types")

-- if health percent is above the key value, use the color
local HEALTH_COLOR_MAP = {
	{ threshold = 100, color = Color3.fromRGB(255,255,255) },
	{ threshold = 60, color = Color3.fromRGB(255,255,0) },
	{ threshold = 25, color = Color3.fromRGB(255,165,0) },
	{ threshold = 1, color = Color3.fromRGB(255,0,0) },
	{ threshold = 0, color = Color3.fromRGB(0, 0, 0) },
}

return function(props: Types.NameTagProps)
	local percent = derive(function()
		if props.maxHealth() == 0 then
			return 0
		end
		return (props.health() / props.maxHealth()) * 100
	end)

	local healthColor = derive(function()
		local percent = percent()
		for _, entry in HEALTH_COLOR_MAP do
			if percent >= entry.threshold then
				return entry.color
			end
		end
		return Color3.fromRGB(0, 0, 0)
	end)

	local name = derive(function()
		return `{props.nameTag()} [{math.round(percent())}%]`
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
			TextColor3 = healthColor,
			TextStrokeTransparency = 0.5,
			TextSize = props.textSize,
			FontFace = Font.fromEnum(Enum.Font.RobotoMono),
		},
	}
end
