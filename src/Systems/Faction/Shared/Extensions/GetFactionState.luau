--[[
simplified extension for getting the faction state from a shared point
]]
local RunService = game:GetService("RunService")
local FactionState = require("../Core/State")

local state: FactionState.State

if RunService:IsServer() then
	local runtime = require("@game/ServerScriptService/Systems/Faction/ServerRuntimeLocator").GetRuntime()
	state = runtime.state
else
	local player = game:GetService("Players").LocalPlayer
	if not player then
		error("no localplayer found??")
	end
	local runtimeLocator = require(
		player.PlayerScripts:WaitForChild("Systems"):WaitForChild("Faction"):WaitForChild("ClientRuntimeLocator")
	)
	local runtime = runtimeLocator.GetRuntime()
	state = runtime.state
end

return state :: FactionState.State