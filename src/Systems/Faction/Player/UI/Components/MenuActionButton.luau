local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local Theme = require("../Theme")
local create = Vide.create

return function(props: {
    Position: UDim2,
    AnchorPoint: Vector2,
	Text: string,
	OnActivated: () -> (),
    WindowActive: () -> boolean,
})
	return create "TextButton" {
        Visible = function() return not props.WindowActive() end,

        Position = props.Position,
        AnchorPoint = props.AnchorPoint,
        Size = UDim2.fromScale(0.03, 1),

        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AutoButtonColor = true,
		Activated = props.OnActivated,

        create "UIAspectRatioConstraint" {
            AspectRatio = 2.5,
            DominantAxis = Enum.DominantAxis.Width,
        },

        create "UIStroke" {
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Thickness = 2,
            Color = Theme.TextColor,
            Transparency = 0.5,
        },

		create "TextLabel" {
            Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 0.8),
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
            Text = props.Text,
			TextTransparency = 0.5,
			FontFace = Theme.fontH2,
			TextColor3 = Theme.TextColor,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Center,
		},
	}
end