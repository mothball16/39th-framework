local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local create = Vide.create

local Types = require("@game/ReplicatedStorage/Systems/Aware/Core/Types")

return function(props: Types.PingTagProps)
	Vide.effect(function()
		print(props.name())
	end)
	return create "Frame" {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,

		create "ImageLabel" {
			Size = UDim2.fromScale(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = props.imageId,
		},

		create "TextLabel" {
			Size = UDim2.fromScale(1, 0.25),
			Position = UDim2.new(0, 0, 0.75, 0),
			BackgroundTransparency = 1,
			Text = props.name,
			TextColor3 = Color3.new(1, 1, 1),
			TextStrokeTransparency = 0.5,
			TextScaled = true,
			FontFace = Font.fromEnum(Enum.Font.RobotoMono),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Top,
		},
	}
end
