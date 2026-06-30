--!strict
local Events = require("./Net/Network")

local Access = require("@game/ReplicatedStorage/Aware_Framework/Access")
local NetworkTypes = require("@game/ReplicatedStorage/Aware_Framework/Core/NetworkTypes")
local PingRouter = require("./Net/PingRouter")


Events.RequestPing.SetCallback(PingRouter.ProcessRequestPing)
