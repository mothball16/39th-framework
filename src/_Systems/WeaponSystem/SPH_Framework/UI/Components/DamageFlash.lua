local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local VideRipple = require("@game/ReplicatedStorage/Packages/vide-ripple")
local create, derive = Vide.create, Vide.derive
local Types = require("../Types")
local SequenceEval = require("@game/ReplicatedStorage/SPH_Framework/Utilities/SequenceEval")

local BLEND_ALPHA = 0.5
local RANDOM_ROTATION_RANGE = 15
local THROW_RANGE = 0.2

return function(props: Types.HitmarkerProps, damage: number)
    local lifetime = derive(function()
        return math.clamp(props.TimeElapsed() / props.lifetime, 0, 1)
    end)

    local color = derive(function()
        if typeof(props.color) == "Color3" then
            return props.color
        end
        return SequenceEval.evalColorSequence(props.color, lifetime(), props.smoothingOffset, BLEND_ALPHA)
    end)
    local randomRot = math.rad(
        (math.random() > 0.5 and 0 or 180) 
        + math.random(-RANDOM_ROTATION_RANGE, RANDOM_ROTATION_RANGE))
    local yOff = math.sin(randomRot) * THROW_RANGE
    local xOff = math.cos(randomRot) * THROW_RANGE
    local endPos = UDim2.fromScale(0.5 + xOff, 0.5 + yOff)

    local transValue, trans = VideRipple.useSpring(1, {
        dampingRatio = 1,
    })
    
    local posValue, pos = VideRipple.useSpring(UDim2.fromScale(0.5, 0.5), {
        dampingRatio = 3,
    })

    pos:setGoal(endPos)

    Vide.effect(function()
        local value = lifetime()
        if value > 0.8 then
            trans:setGoal(1)
        elseif value > 0.2 then
            trans:setGoal(0)
        end
    end)

    return create "TextLabel" {
        Name = "Damage",
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Text = tostring(math.floor(damage)),
        TextColor3 = color,
        TextScaled = true,
        Size = props.size,
        TextTransparency = transValue,
        Position = posValue,
    }
    
end
