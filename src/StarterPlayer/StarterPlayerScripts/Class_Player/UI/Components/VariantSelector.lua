local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Vide = require(Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local create = Vide.create

return function(props: {
    title: string,
    titleHeight: number,
    size: UDim2,
    ValueText: () -> string,
    LeftActivated: () -> (),
    RightActivated: () -> (),
})
    return create "Frame" {
        Name = "VariantOption",
        LayoutOrder = 1,
        Size = props.size,

        BackgroundTransparency = 1,
        BorderSizePixel = 0,

        create "TextLabel" {
            Name = "Label",
            AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.fromScale(0.5, 0),
            Size = UDim2.fromScale(1, props.titleHeight),
            BackgroundTransparency = 1,
            Text = props.title,
            TextColor3 = Theme.TextColor,
            TextTransparency = 0.25,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextScaled = true,
            FontFace = Theme.fontH2,
        },

        create "Frame" {
            Name = "Main",
            AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.fromScale(0.5, props.titleHeight),
            Size = UDim2.fromScale(1, 1 - props.titleHeight),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            create "TextButton" {
                Name = "PreviousVariant",
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.fromScale(0, 0.5),
                Size = UDim2.fromScale(0.15, 0.8),
                BackgroundColor3 = Theme.Background,
                BackgroundTransparency = 0.3,
                Text = "<",
                TextColor3 = Theme.TextColor,
                TextScaled = true,
                FontFace = Theme.fontNormal,
                Activated = props.LeftActivated,
            },
    
            create "TextLabel" {
                Name = "VariantValue",
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromScale(0.6, 0.8),
                BackgroundTransparency = 1,
                TextColor3 = Theme.TextColor,
                TextScaled = true,
                FontFace = Theme.fontH2,
                Text = function() return props.ValueText() end,
            },
    
            create "TextButton" {
                Name = "NextVariant",
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.fromScale(1, 0.5),
                Size = UDim2.fromScale(0.15, 0.8),
                BackgroundColor3 = Theme.Background,
                BackgroundTransparency = 0.3,
                Text = ">",
                TextColor3 = Theme.TextColor,
                TextScaled = true,
                FontFace = Theme.fontH2,
                Activated = props.RightActivated,
            },
        }

    }
end