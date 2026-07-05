local ByteNetMax = require("@game/ReplicatedStorage/Packages/bytenet-max")

local namespace = ByteNetMax.defineNamespace("Radio_Framework", function()
    return {
        packets = {
            BuildRadio = ByteNetMax.definePacket({
                value = ByteNetMax.struct({
                    radioType = ByteNetMax.string,
                    radioCF = ByteNetMax.cframe,
                    radioFrequency = ByteNetMax.float32,
                }),
            }),
        },
        queries = {},
    }
end)

return namespace