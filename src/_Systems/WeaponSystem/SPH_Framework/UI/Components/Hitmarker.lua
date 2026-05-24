local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Vide = require(Packages.Vide)
local create, spring, derive = Vide.create, Vide.spring, Vide.derive
local Types = require("../Types")

--#region - - [ utils for sequence values ] - -
local function evalColorSequence(sequence: ColorSequence, time: number)
    -- If time is 0 or 1, return the first or last value respectively
    if time == 0 then
        return sequence.Keypoints[1].Value
    elseif time == 1 then
        return sequence.Keypoints[#sequence.Keypoints].Value
    end

    -- Otherwise, step through each sequential pair of keypoints
    for i = 1, #sequence.Keypoints - 1 do
        local thisKeypoint = sequence.Keypoints[i]
        local nextKeypoint = sequence.Keypoints[i + 1]
        if time >= thisKeypoint.Time and time < nextKeypoint.Time then
            -- Calculate how far alpha lies between the points
            local alpha = (time - thisKeypoint.Time) / (nextKeypoint.Time - thisKeypoint.Time)
            -- Evaluate the real value between the points using alpha
            return Color3.new(
                (nextKeypoint.Value.R - thisKeypoint.Value.R) * alpha + thisKeypoint.Value.R,
                (nextKeypoint.Value.G - thisKeypoint.Value.G) * alpha + thisKeypoint.Value.G,
                (nextKeypoint.Value.B - thisKeypoint.Value.B) * alpha + thisKeypoint.Value.B
            )
        end
    end
    return Color3.new(0, 0, 0)
end

local function evalNumberSequence(sequence: NumberSequence, time: number)
    -- If time is 0 or 1, return the first or last value respectively
    if time == 0 then
        return sequence.Keypoints[1].Value
    elseif time == 1 then
        return sequence.Keypoints[#sequence.Keypoints].Value
    end

    -- Otherwise, step through each sequential pair of keypoints
    for i = 1, #sequence.Keypoints - 1 do
        local currKeypoint = sequence.Keypoints[i]
        local nextKeypoint = sequence.Keypoints[i + 1]
        if time >= currKeypoint.Time and time < nextKeypoint.Time then
            -- Calculate how far alpha lies between the points
            local alpha = (time - currKeypoint.Time) / (nextKeypoint.Time - currKeypoint.Time)
            -- Return the value between the points using alpha
            return currKeypoint.Value + (nextKeypoint.Value - currKeypoint.Value) * alpha
        end
    end
    return 0
end

--#endregion


return function(props: Types.HitmarkerProps)
    assert(props.TimeElapsed, "hitmarker props must have a TimeElapsed. you probably forgot to add it after applying config")
    local lifetime = derive(function()
        return math.clamp(props.TimeElapsed() / props.lifetime, 0, 1)
    end)
    
    local scale = derive(function()
        if typeof(props.scale) == "number" then
            return props.scale
        end
        return evalNumberSequence(props.scale, lifetime())
    end)

    local transparency = derive(function()
        if typeof(props.transparency) == "number" then
            return props.transparency
        end
        return evalNumberSequence(props.transparency, lifetime())
    end)

    local rotation = derive(function()
        if typeof(props.rotation) == "number" then
            return props.rotation
        end
        return evalNumberSequence(props.rotation, lifetime())
    end)

    local color = derive(function()
        if typeof(props.color) == "Color3" then
            return props.color
        end
        return evalColorSequence(props.color, lifetime())
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
        Position = props.position,
        Image = props.image,
        BackgroundTransparency = 1,
        Size = spring(size, props.springPeriod, props.springDamping),
        ImageColor3 = spring(color, props.springPeriod, props.springDamping),
        ImageTransparency = spring(transparency, props.springPeriod, props.springDamping),
        Rotation = spring(rotation, props.springPeriod, props.springDamping),

        create "UIAspectRatioConstraint" {
            AspectRatio = 1
        }
    }
end
