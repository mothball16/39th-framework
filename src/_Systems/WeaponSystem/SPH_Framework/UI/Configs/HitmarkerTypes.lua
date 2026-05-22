--!strict
local UI = script.Parent.Parent
local Hitmarker = require(UI.Components.Hitmarker)

local HitmarkerTypes: {[string]: () -> Hitmarker.HitmarkerProps} = {
    Default = function()
        return {
            springPeriod = 0.2,
            springDamping = 1,
            position = UDim2.fromScale(0.5, 0.5),
            size = UDim2.fromScale(0.03, 1),
            image = "rbxassetid://125718430168410",
            color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
            }),
            transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0),
                NumberSequenceKeypoint.new(0.5, 1),
                NumberSequenceKeypoint.new(1, 1),
            }),
            scale = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1),
                NumberSequenceKeypoint.new(0.5, 3),
                NumberSequenceKeypoint.new(1, 3),
            }),
            rotation = math.random(0, 360),
            lifetime = 0.3,
        } 
    end,
    Headshot = function()
        return {
            springPeriod = 0.2,
            springDamping = 1,
            position = UDim2.fromScale(0.5, 0.5),
            size = UDim2.fromScale(0.2, 0.2),
            image = "rbxassetid://125718430168410",
            color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 118, 118)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
            }),
            transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0),
                NumberSequenceKeypoint.new(0.5, 1),
                NumberSequenceKeypoint.new(1, 1),
            }),
            scale = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1),
                NumberSequenceKeypoint.new(0.5, 3),
                NumberSequenceKeypoint.new(1, 3),
            }),
            rotation = math.random(0, 360),
            lifetime = 0.5,
        }
    end,
}

return HitmarkerTypes