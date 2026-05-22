local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local create = Vide.create

return function(props)
	return create "Frame"{
        Name = "Stroke",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(1, -props.Thickness * 2, 1, -props.Thickness * 2),
        BackgroundTransparency = 1,
        create "UIStroke" (props),
    }
end