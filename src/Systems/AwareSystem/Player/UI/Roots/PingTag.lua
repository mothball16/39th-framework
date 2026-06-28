local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local VideRipple = require("@game/ReplicatedStorage/Packages/vide-ripple")
local create = Vide.create
local ShortenName = require("../Logic/ShortenName")

local Types = require("@game/ReplicatedStorage/Aware_Framework/Core/Types")

return function(props: Types.PingTagProps)
    local name = ShortenName(props.name)
    local transValue, transSpring = VideRipple.useSpring(1)
    transSpring:setGoal(0.25)

    return create "CanvasGroup" {
        GroupTransparency = transValue,
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
            Text = name,
            TextColor3 = Color3.new(1, 1, 1),
            TextStrokeTransparency = 0.5,
            TextScaled = true,
            FontFace = Font.fromEnum(Enum.Font.RobotoMono),
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Top,
        }
    }
end