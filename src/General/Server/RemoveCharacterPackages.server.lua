-- Strips Roblox avatar body packages (Headless, Korblox, etc.) from R6 characters.
-- Keeps clothing and accessories; only resets body-part mesh IDs to default block limbs.

local Players = game:GetService("Players")

local function removeBodyPackages(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R6 then
		return
	end

	local ok, err = pcall(function()
		local description = humanoid:GetAppliedDescription()
		description.Head = 0
		description.Torso = 0
		description.LeftArm = 0
		description.RightArm = 0
		description.LeftLeg = 0
		description.RightLeg = 0
		humanoid:ApplyDescriptionAsync(description)
	end)

	if not ok then
		warn(`[RemoveCharacterPackages] Failed for {character:GetFullName()}: {err}`)
		return
	end

	-- ponytail: R6 CharacterMesh can linger if description apply races load
	for _, child in character:GetChildren() do
		if child:IsA("CharacterMesh") then
			child:Destroy()
		end
	end
end

local function onPlayerAdded(player: Player)
	player.CharacterAppearanceLoaded:Connect(removeBodyPackages)
end

Players.PlayerAdded:Connect(onPlayerAdded)

for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
	if player.Character then
		task.defer(removeBodyPackages, player.Character)
	end
end
