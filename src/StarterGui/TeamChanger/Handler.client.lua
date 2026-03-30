local Parent = script.Parent
local TeamList = Parent.List
local teamTemplate = TeamList.ScrollingFrame.Team:Clone()
TeamList.ScrollingFrame.Team:Destroy()
local function onTeamClick(arg1)
	game.ReplicatedStorage.TeamSelection:FireServer(arg1)
end
;(function()
	for _, team in ipairs(game.Teams:GetChildren()) do
		if team:IsA("Team") and (not team:FindFirstChild("TeamSwitchConfig") or team.TeamSwitchConfig.Listed.Value) then
			local clone = teamTemplate:Clone()
			clone.Text = team.Name
			clone.Name = team.Name
			clone.BackgroundColor3 = team.TeamColor.Color
			clone.Parent = TeamList.ScrollingFrame
			clone.MouseButton1Click:Connect(function()
				game.ReplicatedStorage.TeamSelection:FireServer(team)
			end)
		end
	end
end)()

Parent.Button.MouseButton1Click:Connect(function()
	TeamList.Visible = not TeamList.Visible
end)
