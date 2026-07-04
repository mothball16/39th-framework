local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local create, derive = Vide.create, Vide.derive
local Types = require("../Types")
local SequenceEval = require("@game/ReplicatedStorage/Systems/Weapon/Utilities/SequenceEval")

local BLEND_ALPHA = 0.5

return function(props: Types.HitmarkerProps)
    local lifetime = derive(function()
        return math.clamp(props.TimeElapsed() / props.lifetime, 0, 1)
    end)

    local scale = derive(function()
        if typeof(props.scale) == "number" then
            return props.scale
        end
        return SequenceEval.evalNumberSequence(props.scale, lifetime(), props.smoothingOffset, BLEND_ALPHA)
    end)

    local transparency = derive(function()
        if typeof(props.transparency) == "number" then
            return props.transparency
        end
        return SequenceEval.evalNumberSequence(props.transparency, lifetime(), props.smoothingOffset, BLEND_ALPHA)
    end)

    local rotation = derive(function()
        if typeof(props.rotation) == "number" then
            return props.rotation
        end
        return SequenceEval.evalNumberSequence(props.rotation, lifetime(), props.smoothingOffset, BLEND_ALPHA)
    end)

    local color = derive(function()
        if typeof(props.color) == "Color3" then
            return props.color
        end
        return SequenceEval.evalColorSequence(props.color, lifetime(), props.smoothingOffset, BLEND_ALPHA)
    end)

    local size = derive(function()
        return UDim2.new(
            props.size.X.Scale * scale(),
            props.size.X.Offset * scale(),
            props.size.Y.Scale * scale(),
            props.size.Y.Offset * scale()
        )
    end)

    return create "ImageLabel" {
        Name = "Hitmarker",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = props.Position,
        Image = props.image,
        BackgroundTransparency = 1,
        Size = size,
        ImageColor3 = color,
        ImageTransparency = transparency,
        Rotation = rotation,

        create "UIAspectRatioConstraint" {
            AspectRatio = 1
        }
    }
end
