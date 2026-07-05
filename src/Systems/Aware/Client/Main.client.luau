--!strict

require("@game/ReplicatedStorage/Packages/Charm").flags.frozen = false

local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")

local localPlayer = Players.LocalPlayer

local Types = require("@game/ReplicatedStorage/Systems/Aware/Core/Types")
local UserSettings = require("./Core/UserSettings")
local PingRequester = require("./Ping/PingRequester")
local ClientState = require("./Core/ClientState")
local GetPlayerSlice = require("@game/ReplicatedStorage/Systems/Aware/Selectors/GetPlayerSlice")

local Charm = require("@game/ReplicatedStorage/Packages/Charm")
local computed = Charm.computed

local SetupClientSync = require("./Net/SetupClientSync")
SetupClientSync(ClientState)

local PingStateSync = require("./Ping/PingStateSync")
PingStateSync(localPlayer, ClientState)

local playerSlice = GetPlayerSlice(localPlayer, ClientState)

local ownedValues = computed(function(): Types.OwnedValues?
	return ClientState.valuesByPlayer()[playerSlice.playerKey]
end)

local mainPing = computed(function(): Types.PingInfo?
	local values = ownedValues()
	return if values then values.Pings["Main"] else nil
end)

local ownedPings = computed(function(): { [string]: Types.PingInfo }
	local values = ownedValues()
	return if values then values.Pings else {}
end)

local mainPingPos = computed(function(): Vector3?
	local curPing = mainPing()
	return if curPing then curPing.position else nil
end)

UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == UserSettings.PingKey() then
		PingRequester.EvaluatePing(mainPingPos(), UIS:GetMouseLocation())
	elseif input.KeyCode == UserSettings.ClearPingKey() then
		PingRequester.EvaluateRemovePing(ownedPings(), UIS:GetMouseLocation())
	end
end)
