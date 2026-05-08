local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Net = require(Packages.Net)


local Events = {
   RequestState = Net:RemoteEvent("RequestState"),
   SyncState = Net:RemoteEvent("SyncState"),
   RequestClass = Net:RemoteEvent("RequestClass"),
   RequestFaction = Net:RemoteEvent("RequestFaction"),
   RequestApplyClass = Net:RemoteEvent("RequestApplyClass"),
}
export type Events = typeof(Events)

return Events