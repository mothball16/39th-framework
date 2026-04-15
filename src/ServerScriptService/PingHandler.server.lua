local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local sph = require(ReplicatedStorage.SPH_Framework.Core.GameAccess)
local BridgeNet = require(sph.framework.Network.BridgeNet) -- your location of bridgenet module
local server = BridgeNet.CreateBridge("PingEvent")

server:Connect(function(player, position)
	local team = player.Team
	if not team then return end

	for _, other in ipairs(Players:GetPlayers()) do
		if other.Team == team then
			server:FireTo(other, player, position)
		end
	end
end)
