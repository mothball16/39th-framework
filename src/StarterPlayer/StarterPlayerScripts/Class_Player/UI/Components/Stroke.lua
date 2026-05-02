local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Vide = require(Packages.Vide)
local create = Vide.create

return function(props: {
	Color: Color3,
	Thickness: number,
	LineJoinMode: Enum.LineJoinMode,
})
	return create "Frame"{
        Name = "Stroke",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(1, -props.Thickness * 2, 1, -props.Thickness * 2),
        BackgroundTransparency = 1,
        
        create "UIStroke" {
            Color = props.Color,
            LineJoinMode = props.LineJoinMode,
            Thickness = props.Thickness,
        },
    }
end