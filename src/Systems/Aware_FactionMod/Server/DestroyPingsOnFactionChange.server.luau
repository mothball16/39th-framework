--!strict
--[[
this script clears player pings upon a faction change
this should honestly 99% be useless as factions typically change based off teams (already integrated),
but it's here on the off-chance factions are used without a dependence on teams
]]
local ServerRuntimeLocator = require("@game/ServerScriptService/Faction_Server/ServerRuntimeLocator")
local Charm = require("@game/ReplicatedStorage/Packages/Charm")
local FactionTypes = require("@game/ReplicatedStorage/Faction_Framework/Core/Types")
local AwareNetwork = require("@game/ServerScriptService/Aware_Server/Net/Network")
local Players = game:GetService("Players")

local runtime = ServerRuntimeLocator.GetRuntime()
local playerAssignments = runtime.state.playerAssignmentByUserId

Charm.observe(playerAssignments, function(item: FactionTypes.PlayerAssignment, key: FactionTypes.PlayerKey)
    local player = Players:GetPlayerByUserId(tonumber(key) :: number)
    local unmount = Charm.effectScope(function()
        local factionId = Charm.computed(function()
            return playerAssignments()[key].FactionId
        end)
        
        Charm.effect(function()
            factionId()
            if player then
                AwareNetwork.ReportRemovePing.FireAll({owner = player})	
            end
        end)
    end)
    
    return unmount
end)
