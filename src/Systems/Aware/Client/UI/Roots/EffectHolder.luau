local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local create = Vide.create

return function(props: {
    
})
    return create "Frame" {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = props.effect,
    }
end