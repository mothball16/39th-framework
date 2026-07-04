--!strict

require("@game/ReplicatedStorage/Packages/Charm").flags.frozen = false

local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")

local localPlayer = Players.LocalPlayer
local cam = workspace.CurrentCamera

local Access = require("@game/ReplicatedStorage/Systems/Aware/Access")
local Config = Access.config
local UserSettings = require("./Core/UserSettings")
local Network = require("./Net/Network")
--local PingTagRenderer = require("./Ping/PingTagRenderer")
local PingRequester = require("./Ping/PingRequester")
local ClientState = require("./Core/ClientState")
local GetPlayerSlice = require("@game/ReplicatedStorage/Systems/Aware/Selectors/GetPlayerSlice")

local SetupClientSync = require("./Net/SetupClientSync")
SetupClientSync(ClientState)

local PingStateSync = require("./Ping/PingStateSync")
PingStateSync(localPlayer, ClientState)


UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == UserSettings.PingKey() then
        PingRequester.EvaluatePing(UIS:GetMouseLocation())
    elseif input.KeyCode == UserSettings.ClearPingKey() then
        PingRequester.EvaluateRemovePing(UIS:GetMouseLocation())
    end
end)
