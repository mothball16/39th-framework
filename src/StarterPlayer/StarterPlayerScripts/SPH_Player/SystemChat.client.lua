local playerServer = game:GetService("Players")
local starterGui = game:GetService("StarterGui")
local replicatedStorage = game:GetService("ReplicatedStorage")
local sph = require(replicatedStorage.SPH_Framework.Core.GameAccess)

local bridgeNet = require(sph.framework.Network.BridgeNet)
local sysMessage = bridgeNet.CreateBridge("SystemMessage")

local textChatService = game:GetService("TextChatService")
local legacyChat = textChatService.ChatVersion == Enum.ChatVersion.LegacyChatService

local config = sph.config

task.wait(2)

if config.systemChat then
	if legacyChat then
		sysMessage:Connect(function(message,color)
			if legacyChat then
				starterGui:SetCore("ChatMakeSystemMessage",{
					Text = message,
					Color = color,
				})
			else
				
			end
		end)
	end
end