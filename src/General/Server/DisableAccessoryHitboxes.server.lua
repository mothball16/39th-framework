local Players = game:GetService("Players")

local function disableAccessoryHitbox(character)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Parent:IsA("Accessory") then
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end
end

local function onCharacterAdded(character)
	disableAccessoryHitbox(character)
	character.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") and descendant.Parent:IsA("Accessory") then
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end)
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		onCharacterAdded(player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end