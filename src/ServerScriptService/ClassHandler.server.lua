local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local TClasses = ReplicatedStorage:WaitForChild("TClasses")
local ClassRemote = TClasses:WaitForChild("ClassRemote")

local function clearPlayerGear(player)
	for _, item in ipairs(player.Backpack:GetChildren()) do
		item:Destroy()
	end
	local char = player.Character
	if char then
		for _, tool in ipairs(char:GetChildren()) do
			if tool:IsA("Tool") then
				tool:Destroy()
			end
		end
	end
end

ClassRemote.OnServerEvent:Connect(function(player, class)
	if typeof(class) == "string" and class == "CLEARCLASS" then
		clearPlayerGear(player)
		return
	end

	if typeof(class) ~= "Instance" or not class:IsDescendantOf(TClasses.Classes) then
		return
	end

	local limit = class:FindFirstChild("Limit")
	if limit and limit.Value >= limit.MaxValue then
		return
	end

	local team = class.Value
	if team and player.Team ~= team then
		player.Team = team
	end

	clearPlayerGear(player)

	local storageClass = ServerStorage:FindFirstChild(class.Name)
	if not storageClass then
		return
	end

	for _, item in ipairs(storageClass:GetChildren()) do
		if item:IsA("Tool") or item:IsA("Accessory") then
			item:Clone().Parent = player.Backpack
		end
	end

	if limit then
		limit.Value += 1
	end
end)
