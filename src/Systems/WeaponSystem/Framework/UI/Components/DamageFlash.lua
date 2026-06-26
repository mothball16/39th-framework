local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local VideRipple = require("@game/ReplicatedStorage/Packages/vide-ripple")
local create, derive = Vide.create, Vide.derive
local Types = require("../Types")
local SequenceEval = require("@game/ReplicatedStorage/SPH_Framework/Utilities/SequenceEval")
local Consts = require("../Data/Consts")

local BLEND_ALPHA = 0.5
local RANDOM_ROTATION_RANGE = 15

local function RANDF(min, max)
    return math.random(min * 100000, max * 100000) / 100000
end

return function(props: Types.HitmarkerProps, damage: number)
    local size = UDim2.fromScale(1, Consts.DAMAGE_FLASH_TEXTSCALE)

    local lifetime = derive(function()
        return math.clamp(props.TimeElapsed() / Consts.DAMAGE_FLASH_LIFETIME, 0, 1)
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
    local yOff = math.sin(randomRot) * Consts.DAMAGE_FLASH_THROW_RANGE * RANDF(0.8, 1.2)
    local xOff = math.cos(randomRot) * Consts.DAMAGE_FLASH_THROW_RANGE * RANDF(0.8, 1.2)
    local endPos = UDim2.fromScale(0.5 + xOff, 0.5 + yOff)

    local transValue, trans = VideRipple.useSpring(1, {
        dampingRatio = 1,
    })

    trans:setGoal(0)
    
    local posValue, pos = VideRipple.useSpring(UDim2.fromScale(0.5, 0.5), {
        dampingRatio = 2,
        mass = 0.5,
        frequency = 3,
        tension = 1000,
    })

    pos:setGoal(endPos)

    Vide.effect(function()
        local value = lifetime()
        if value > 0.67 then
            trans:setGoal(1)
        end
    end)

    return create "TextLabel" {
        Name = "Damage",
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        RichText = true,
        Text = `<b>{tostring(math.floor(damage))}</b>`,
        TextStrokeTransparency = 0.8,
        Font = Enum.Font.RobotoMono,
        TextColor3 = color,
        TextScaled = true,
        Size = size,
        TextTransparency = transValue,
        Position = posValue,
    }
    
end
