local ByteNetMax = require("@game/ReplicatedStorage/Packages/bytenet-max")
local Net = require("@game/ReplicatedStorage/Packages/Net")

local legacyEvents = {
   RequestState = Net:RemoteEvent("RequestState"),
   SyncState = Net:RemoteEvent("SyncState"),
}

local Events = {}
function Events.GetLegacyEvents()
   return legacyEvents
end


function Events.GetNamespace()   
   return ByteNetMax.defineNamespace("Faction_Framework", function()
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
end

return Events
