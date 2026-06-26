local Vide = require("@game/ReplicatedStorage/Packages/Vide")

local source = Vide.source
local create = Vide.create
local derive = Vide.derive
return function(props: {
    health: () -> number,
    maxHealth: () -> number,
    username: () -> string,
})
    local percent = derive(function()
        return props.health() / props.maxHealth()
    end)
    local name = derive(function()
        return `{string.sub(props.username(), 1, 4)} [{math.round(percent() * 100)}%]`
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
            FontFace = Font.fromEnum(Enum.Font.RobotoMono)
        }
    }
end