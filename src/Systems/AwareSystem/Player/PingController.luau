local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local create = Vide.create

local PingTag = require("./UI/Roots/PingTag")

local PingController = {}


function PingController.CreatePingTag(imageId: string, name: string)
    local pingTag = create "BillboardGui" {
        AlwaysOnTop = true,

    }

    return pingTag
end

return PingController