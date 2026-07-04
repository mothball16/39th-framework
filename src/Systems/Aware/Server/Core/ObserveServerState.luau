--!strict
--[[
observes and updates the state of the 
]]
local Types = require("@game/ReplicatedStorage/Systems/Aware/Core/Types")
local Access = require("@game/ReplicatedStorage/Systems/Aware/Access")
local Maid = require("@game/ReplicatedStorage/Packages/maid")
local Charm = require("@game/ReplicatedStorage/Packages/Charm")
local trigger = Charm.trigger
local Players = game:GetService("Players")

local function spawnDisconnectable(fn: () -> ())
    local thread = task.spawn(fn)
    return function()
        task.cancel(thread)
    end
end

return function(state: Types.State)
    local maid = Maid.new()

    maid:GiveTask(Players.PlayerAdded:Connect(function(player)
        state.valuesByPlayer()[player] = {
            Team = Access.config.GetTeamValue(player),
            Pings = {} :: { [Player]: Types.PingInfo },
        }
        trigger(state.valuesByPlayer)
    end))

    maid:GiveTask(Players.PlayerRemoving:Connect(function(player)
        state.valuesByPlayer()[player] = nil
        trigger(state.valuesByPlayer)
    end))

    maid:GiveTask(spawnDisconnectable(function()
        -- polling loop to update teams per player
        while task.wait(Access.config.TeamUpdateInterval) do
            local dirty = false
            for player, ownedValues in state.valuesByPlayer() do
                local team = Access.config.GetTeamValue(player)
                if team ~= ownedValues.Team then
                    ownedValues.Team = team
                    dirty = true
                end
            end

            if dirty then
                trigger(state.valuesByPlayer)
            end
        end
    end))

    return function()
        maid:DoCleaning()
    end
end