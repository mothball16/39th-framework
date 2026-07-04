local NetworkTypes = require("@game/ReplicatedStorage/Systems/Aware/Core/NetworkTypes")
local Access = require("@game/ReplicatedStorage/Systems/Aware/Access")
local Players = game:GetService("Players")
local Events = require("./Network")

local PingRouter = {}

function PingRouter.ProcessRequestPing(player: Player, inbound: NetworkTypes.RequestPingPayload)
    local team = Access.config.GetTeamValue(player)
    for _, receiver in Players:GetPlayers() do
        if Access.config.ReplicateToSelf and receiver == player then continue end
        if Access.config.GetTeamValue(receiver) == team then
            local outbound: NetworkTypes.ReportPingPayload = {
                position = inbound.position,
                owner = player,
                name = player.DisplayName,
            }
            Events.ReportPing.Fire(receiver, outbound)
        end
    end
end


function PingRouter.ProcessRequestRemovePing(player: Player)
    local team = Access.config.GetTeamValue(player)
    for _, receiver in Players:GetPlayers() do
        if Access.config.ReplicateToSelf and receiver == player then continue end
        if Access.config.GetTeamValue(receiver) == team then
            Events.ReportRemovePing.Fire(receiver, {
                owner = player,
            })
        end
    end
end

return PingRouter