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
   return ByteNetMax.defineNamespace("Class_Framework", function()
      return {
         packets = {
            RequestGroupClass = ByteNetMax.definePacket({
               value = ByteNetMax.struct({
                  group = ByteNetMax.string,
                  class = ByteNetMax.string,
               }),
            }),
            RequestFaction = ByteNetMax.definePacket({
               value = ByteNetMax.struct({
                  factionId = ByteNetMax.string,
               }),
            }),
            RequestClassApply = ByteNetMax.definePacket({
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





-- local Net = require(Packages.Net)

-- local Events = {
--    RequestState = Net:RemoteEvent("RequestState"),
--    SyncState = Net:RemoteEvent("SyncState"),
--    RequestGroupClass = Net:RemoteEvent("RequestGroupClass"),
--    RequestFaction = Net:RemoteEvent("RequestFaction"),
--    RequestClassApply = Net:RemoteEvent("RequestClassApply"),
-- }
-- export type Events = typeof(Events)

-- return Events