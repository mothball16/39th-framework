
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Remotes = ReplicatedStorage:WaitForChild("ClassRemotes")
local RequestClass = Remotes.RequestClass
local UpdateCounts = Remotes.UpdateCounts

-- CLASSES
local Classes = {
	["NOOBIC MARINE CORPS"] = {
		Rifleman = {"D-19A1", "DX-21"},
		Machinegunner = {"C-11", "DX-21"},
		AntiTank = {"PAT-1", "D-19A1"},
		Marksman = {"KZW", "DX-21PC"},
		Engineer = {"D-23", "DX-21", "AT Landmines x2", "AP Landmines x3", "Sandbags x3", "Hammer"},
		Scout = {"D-19AX2", "DX-21", "Bandage"},
	},
	
	["FEDERAL MARITIME DEFENSE FORCES"] = {
		Rifleman = {"BR-10", "M19"},
		Machinegunner = {"B-63", "M19"},
		AntiTank = {"R-72", "BR-18S"},
		Marksman = {"AT-42", "M19"},
		Engineer = {"BR-18G", "AT Landmines x2", "AP Landmines x3", "Hammer"},
		Scout = {"BR-18S PDW", "M19", "Bandage"},
	},
	
	["AWAITING DEPLOYMENT"] = {}
}

-- CLASS LIMITS
local Limits = {
	Rifleman = 100,
	Machinegunner = 4,
	AntiTank = 8,
	Scout= 2,
	Engineer = 2,
	Marksman = 2
}


local Counts = {} -- Counts[teamName][className] = number

local function recount()
	table.clear(Counts)

	for _, plr in Players:GetPlayers() do
		local class = plr:GetAttribute("Class")
		local team = plr.Team and plr.Team.Name

		if class and team and team ~= "Lobby" then
			Counts[team] = Counts[team] or {}
			Counts[team][class] = (Counts[team][class] or 0) + 1
		end
	end

	UpdateCounts:FireAllClients(Counts)
end

local function giveTools(player, className)
	local teamName = player.Team and player.Team.Name
	if not teamName or teamName == "Lobby" then return end

	local loadout = Classes[teamName] and Classes[teamName][className]
	if not loadout then return end

	for _, toolName in ipairs(loadout) do
		local tool = ServerStorage.Tools:FindFirstChild(toolName)
		if tool then
			tool:Clone().Parent = player.Backpack
		end
	end
end

Players.PlayerRemoving:Connect(recount)

RequestClass.OnServerEvent:Connect(function(player, className)
	local current = player:GetAttribute("Class") or "Rifleman"

	-- already same class
	if current == className then return end

	-- check limit
	local limit = Limits[className]
	local team = player.Team and player.Team.Name
	local teamCounts = Counts[team] or {}

	if limit and (teamCounts[className] or 0) >= limit then
		RequestClass:FireClient(player, false)
		return
	end

	player:SetAttribute("Class", className)
	player:LoadCharacter()

	recount()

	RequestClass:FireClient(player, true)
end)

local function onCharacterAdded(player)
	local class = player:GetAttribute("Class") or "Rifleman"

	task.wait(0.2)
	giveTools(player, class)
	recount()
end


-- update counts on respawn
Players.PlayerAdded:Connect(function(player)
	player:SetAttribute("Class", "Rifleman")

	player.CharacterAdded:Connect(function()
		onCharacterAdded(player)
	end)
end)
