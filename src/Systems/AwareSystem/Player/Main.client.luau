local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer
local cam = workspace.CurrentCamera

local Access = require("@game/ReplicatedStorage/Aware_Framework/Access")
local Config = Access.config
local UserSettings = require("./Core/UserSettings")
local Network = require("./Net/Network")
local PingController = require("./Ping/PingController")
local PingInputHandler = require("./Ping/PingInputHandler")

local ClientState = require("./Core/ClientState")

local SetupClientSync = require("./Net/SetupClientSync")
SetupClientSync(ClientState)

local PingStateSync = require("./Ping/PingStateSync")
PingStateSync(localPlayer, ClientState)


Network.ReportPing.On(function(data)
    PingController.RegisterPingTag(data.owner, data.position, {
        imageId = Config.PingImageId,
        name = data.name,
        size = UserSettings.PingSize,
    })
end)

Network.ReportRemovePing.On(function(data)
    PingController.DeletePingTag(data.owner)
end)

UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == UserSettings.PingKey() then
        PingInputHandler.EvaluatePing(UIS:GetMouseLocation())
    elseif input.KeyCode == UserSettings.ClearPingKey() then
        PingInputHandler.EvaluateRemovePing(UIS:GetMouseLocation())
    end
end)