local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local create = Vide.create

return function(props: {
	text: string,
	layoutOrder: number?,
	onActivated: () -> (),
})
	return create "TextButton" {
		LayoutOrder = props.layoutOrder or 0,
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundColor3 = Color3.fromRGB(45, 45, 45),
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Text = props.text,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextScaled = true,
		Font = Enum.Font.GothamMedium,
		Activated = props.onActivated,
	}
end
