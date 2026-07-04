require("@game/ReplicatedStorage/Packages/Charm").flags.frozen = false

local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")

local localPlayer = Players.LocalPlayer
local cam = workspace.CurrentCamera

local Access = require("@game/ReplicatedStorage/Systems/Aware/Access")
local Config = Access.config
local UserSettings = require("./Core/UserSettings")
local Network = require("./Net/Network")
--local PingController = require("./Ping/PingController")
local PingInputHandler = require("./Ping/PingInputHandler")
local ClientState = require("./Core/ClientState")

local SetupClientSync = require("./Net/SetupClientSync")
SetupClientSync(ClientState)

local PingStateSync = require("./Ping/PingStateSync")
PingStateSync(localPlayer, ClientState)


UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == UserSettings.PingKey() then
        PingInputHandler.EvaluatePing(UIS:GetMouseLocation())
    elseif input.KeyCode == UserSettings.ClearPingKey() then
        PingInputHandler.EvaluateRemovePing(UIS:GetMouseLocation())
    end
end)
