--!strict
require("@game/ReplicatedStorage/Packages/Charm").flags.frozen = false

local Events = require("./Net/Network")

local PingRouter = require("./Net/PingRouter")
local SetupServerSync = require("./Net/SetupServerSync")
local BindPlayersToState = require("./Core/BindPlayersToState")
local ServerState = require("./Core/ServerState")

BindPlayersToState(ServerState)
SetupServerSync(ServerState)

Events.RequestPing.SetCallback(PingRouter.ProcessRequestPing)
Events.RequestRemovePing.SetCallback(PingRouter.ProcessRequestRemovePing)
