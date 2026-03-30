local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BridgeNet = require(ReplicatedStorage:WaitForChild("SPH_Assets").Modules.BridgeNet) -- your location of bridgenet module
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
