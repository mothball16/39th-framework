local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

local event = ReplicatedStorage:WaitForChild("TeamSelection")

event.OnServerEvent:Connect(function(player, selectedTeam)
	if typeof(selectedTeam) == "Instance" and selectedTeam:IsA("Team") then
		player.Team = selectedTeam
		player.Neutral = false
		player:LoadCharacter()
	end
end)
