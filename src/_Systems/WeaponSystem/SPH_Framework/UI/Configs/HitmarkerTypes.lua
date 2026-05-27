--!strict
local Types = require("../Types")
local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local source = Vide.source
local HitmarkerTypes: {[string]: () -> Types.HitmarkerProps} = {
    Default = function()
        return {
            smoothingOffset = 0.25,
            soundType = "Default",
            TimeElapsed = source(0),
            position = UDim2.fromScale(0.5, 0.5),
            size = UDim2.fromScale(0.025, 1),
            image = "rbxassetid://125718430168410",
            color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
            }),
            transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0),
                NumberSequenceKeypoint.new(0.5, 0),
                NumberSequenceKeypoint.new(1, 1),
            }),
            scale = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1),
                -- NumberSequenceKeypoint.new(0.5, 3),
                NumberSequenceKeypoint.new(1, 3),
            }),
            rotation = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 45),
                NumberSequenceKeypoint.new(1, 45 + math.random(-15, 15)),
            }),
            lifetime = 0.25,
        } 
    end,
    Headshot = function()
        return {
            smoothingOffset = 0.25,
            soundType = "Headshot",
            TimeElapsed = source(0),
            position = UDim2.fromScale(0.5, 0.5),
            size = UDim2.fromScale(0.035, 1),
            image = "rbxassetid://125718430168410",
            color =  Color3.fromRGB(255, 118, 118),
            transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0),
                NumberSequenceKeypoint.new(0.5, 0),
                NumberSequenceKeypoint.new(1, 1),
            }),
            scale = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1),
                -- NumberSequenceKeypoint.new(0.8, 4),
                NumberSequenceKeypoint.new(1, 3),
            }),
            rotation = 45,--math.random(0, 360),
            lifetime = 0.35,
        }
    end,
    Test = function()
        return {
            smoothingOffset = 0.2,
            soundType = "Default",
            TimeElapsed = source(0),
            position = UDim2.fromScale(0.5, 0.5),
            size = UDim2.fromScale(0.2, 0.2),
            image = "rbxassetid://125718430168410",
            color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(math.random(0, 255), math.random(0, 255), math.random(0, 255))),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(math.random(0, 255), math.random(0, 255), math.random(0, 255))),
            }),
            transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0),
                NumberSequenceKeypoint.new(1, math.random(0, 1)),
            }),
            scale = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1),
                NumberSequenceKeypoint.new(1, math.random(20, 30) / 10),
            }),
            rotation = math.random(0, 360),
            lifetime = math.random(20, 50) / 100,
        } 
    end,
}

return HitmarkerTypes