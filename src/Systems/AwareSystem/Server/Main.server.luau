--!strict
local Events = require("./Net/Network")

local Access = require("@game/ReplicatedStorage/Aware_Framework/Access")
local NetworkTypes = require("@game/ReplicatedStorage/Aware_Framework/Core/NetworkTypes")
local PingRouter = require("./Net/PingRouter")
local SetupServerSync = require("./Net/SetupServerSync")
local ObserveServerState = require("./Core/ObserveServerState")
local ServerState = require("./Core/ServerState")

ObserveServerState(ServerState)
SetupServerSync(ServerState)

Events.RequestPing.SetCallback(PingRouter.ProcessRequestPing)

