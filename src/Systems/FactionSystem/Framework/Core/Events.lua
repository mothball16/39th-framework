local ByteNetMax = require("@game/ReplicatedStorage/Packages/bytenet-max")
local Events = ByteNetMax.defineNamespace("Faction_Framework", function()
   return {
      packets = {
         RequestClassVariant = ByteNetMax.definePacket({
            value = ByteNetMax.struct({
               class = ByteNetMax.string,
               variant = ByteNetMax.string,
            }),
         }),
         RequestFaction = ByteNetMax.definePacket({
            value = ByteNetMax.struct({
               factionId = ByteNetMax.string,
            }),
         }),
         RequestVariantApply = ByteNetMax.definePacket({
            value = ByteNetMax.struct({
               enable = ByteNetMax.bool,
            }),
         }),
      },
      queries = {},
   }
end)

return Events
