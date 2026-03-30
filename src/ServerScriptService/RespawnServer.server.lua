local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RespawnEvent = ReplicatedStorage:WaitForChild("RespawnPlayer")

RespawnEvent.OnServerEvent:Connect(function(player)
	if player then
		player:LoadCharacter()
	end
end)