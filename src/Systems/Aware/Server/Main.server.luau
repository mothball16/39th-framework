--!strict
require("@game/ReplicatedStorage/Packages/Charm").flags.frozen = false

local Events = require("./Net/Network")

local Access = require("@game/ReplicatedStorage/Systems/Aware/Access")
local NetworkTypes = require("@game/ReplicatedStorage/Systems/Aware/Core/NetworkTypes")
local PingRouter = require("./Net/PingRouter")
local SetupServerSync = require("./Net/SetupServerSync")
local BindPlayersToState = require("./Core/BindPlayersToState")
local ServerState = require("./Core/ServerState")

BindPlayersToState(ServerState)
SetupServerSync(ServerState)

Events.RequestPing.SetCallback(PingRouter.ProcessRequestPing)

