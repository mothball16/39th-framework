local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local create, source, indexes, effect, derive = Vide.create, Vide.source, Vide.indexes, Vide.effect, Vide.derive
local Hitmarker = require("../Components/Hitmarker")
local Types = require("../Types")

return function(props: Types.EffectViewProps)    
    return create "Frame" {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        indexes(props.activeHitmarkers, function(item, index)
            return Hitmarker(item())
        end),
    }
end