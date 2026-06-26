--!strict
local Events = require("./Network")

local Access = require("@game/ReplicatedStorage/Aware_Framework/Access")
local NetworkTypes = require("@game/ReplicatedStorage/Aware_Framework/Core/NetworkTypes")
local PingRouter = require("./PingRouter")


Events.RequestPing.SetCallback(PingRouter.ProcessRequestPing)
