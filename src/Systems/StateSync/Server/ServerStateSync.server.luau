--!strict
local Players = game:GetService("Players")

local Server = require("@game/ReplicatedStorage/Packages/charm-sync").server
local Events = require("./Network")

Server.connect(function(player, updates)
	print("connect", player.Name, updates)
	Events.SyncState.Fire(player, updates)
end)

Players.PlayerRemoving:Connect(function(player)
	Server.removeClient(player)
end)

