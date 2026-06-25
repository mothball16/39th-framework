-- Strips Roblox avatar limb packages (Korblox, etc.) from characters and neutralizes Headless heads.
-- Limb packages are always removed. Headless heads are restored to a visible default R6 head.
-- All other heads (including dynamic heads, which carry the player's face) are left untouched,
-- so faces always persist.

local Players = game:GetService("Players")

-- Catalog HumanoidDescription.Head IDs for invisible / headless heads.
local HEADLESS_HEAD_IDS = {
	[134082579] = true, -- Headless Horseman (classic Headless Head)
	[15093053680] = true, -- Dynamic Headless Head
	[2499611582] = true, -- alternate invisible head
	[2490664239] = true, -- common UGC invisible head
	[15092945054] = true, -- robot mech mobility
}

-- ponytail: mesh-id fallback for copycat UGC that reuses the same invisible meshes
local HEADLESS_MESH_NUMBERS = {
	["134079402"] = true, -- classic headless mesh (134082579 / 15093053680)
	["2588190330"] = true, -- 2499611582
	["2506113769"] = true, -- 2490664239
}

local DEFAULT_FACE = "rbxasset://textures/face.png"

local function stripLimbPackages(character: Model)
	-- limb packages are extra CharacterMesh instances; default limbs have none
	for _, child in character:GetChildren() do
		if child:IsA("CharacterMesh") then
			child:Destroy()
		end
	end
end

local function restoreDefaultHead(head: BasePart)
	-- classic R6 head shape comes from a SpecialMesh "Mesh"; if it's missing this isn't a
	-- classic head (e.g. R15 MeshPart head) so we leave it alone
	local mesh = head:FindFirstChildOfClass("SpecialMesh")
	if not mesh then
		return
	end

	mesh.MeshId = ""
	mesh.TextureId = ""
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	mesh.Offset = Vector3.zero
	head.Size = Vector3.new(2, 1, 1)
	head.Transparency = 0

	-- headless players have no Face asset, so give them the default face
	local face = head:FindFirstChild("face") or head:FindFirstChild("Face")
	if not (face and face:IsA("Decal")) then
		face = Instance.new("Decal")
		face.Name = "face"
		face.Face = Enum.NormalId.Front
		face.Parent = head
	end
	if face.Texture == "" then
		face.Texture = DEFAULT_FACE
	end
end

local function isHeadless(character: Model): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end

	local ok, description = pcall(function()
		return humanoid:GetAppliedDescription()
	end)
	if ok and HEADLESS_HEAD_IDS[description.Head] then
		return true
	end

	local head = character:FindFirstChild("Head")
	local mesh = head and head:FindFirstChildOfClass("SpecialMesh")
	local meshNumber = mesh and string.match(mesh.MeshId, "%d+")
	return meshNumber ~= nil and HEADLESS_MESH_NUMBERS[meshNumber] == true
end

local function removeBodyPackages(character: Model)
	stripLimbPackages(character)

	if isHeadless(character) then
		local head = character:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			restoreDefaultHead(head)
		end
	end
end

local function onPlayerAdded(player: Player)
	player.CharacterAppearanceLoaded:Connect(removeBodyPackages)
	if player.Character then
		task.defer(removeBodyPackages, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
