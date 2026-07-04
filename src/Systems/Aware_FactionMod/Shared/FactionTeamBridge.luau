--[[
creates the team-check function based off of the player faction instead of the team value
in retrospect - player attributes may be a smarter choice, consider rebuilding this in the future
]]

local RunService = game:GetService("RunService")

local Types = require("@game/ReplicatedStorage/Aware_Framework/Core/Types")

local FactionState = require("@game/ReplicatedStorage/Faction_Framework/Core/State")
local Utilities = require("@game/ReplicatedStorage/Faction_Framework/Logic/Utilities")

local state: FactionState.State

if RunService:IsServer() then
	local runtime = require("@game/ServerScriptService/Faction_Server/ServerRuntimeLocator").GetRuntime()
	state = runtime.state
else
	local player = game:GetService("Players").LocalPlayer
	if not player then error("no localplayer found??") end
	local runtimeLocator = require(player.PlayerScripts:WaitForChild("Faction_Player"):WaitForChild("ClientRuntimeLocator"))
	local runtime = runtimeLocator.GetRuntime()
	state = runtime.state
end

return function(player: Player): string?
	local assignment = state.playerAssignmentByUserId()[Utilities.ToPlayerKey(player.UserId)]
	return assignment and assignment.FactionId or nil
end