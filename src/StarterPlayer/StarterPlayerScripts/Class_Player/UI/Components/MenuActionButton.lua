local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Vide = require(Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local create = Vide.create

return function(props: {
    Position: UDim2,
	Text: string,
	OnActivated: () -> (),
    WindowActive: () -> boolean,
})
	return create "TextButton" {
        Visible = function() return not props.WindowActive() end,

        Position = props.Position,
        Size = UDim2.fromScale(0.05, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AutoButtonColor = true,
		Activated = props.OnActivated,

        create "UIAspectRatioConstraint" {
            AspectRatio = 2.5,
            DominantAxis = Enum.DominantAxis.Width,
        },

        create "UIStroke" {
            Thickness = 2,
            Color = Theme.AccentColor,
            Transparency = 0,
        },

		create "TextLabel" {
            Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 0.8),
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
            Text = props.Text,
			FontFace = Theme.fontH2,
			TextColor3 = Theme.TextColor,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Center,
		},
	}
end