-- VARIABLES
local ui = script.Parent
local frame = ui.Frame

local defs = frame.Marines
local raids = frame.Officers

local config = game.ReplicatedStorage['3NDConfigs']

local Marines = 0
local Officers = 0

local defFormat = '/N/ MARINE(S) ONLINE'
local raidFormat = '/N/ RAIDERS(S) ONLINE'
	
-- FUNCTIONS
local function defsChanged(n)
	Marines += n
	defs.Text = string.gsub(defFormat, '/N/', tostring(Marines))
end

local function raidsChanged(n)
	Officers += n
	raids.Text = string.gsub(raidFormat, '/N/', tostring(Officers))
end

-- EXECUTION
defs.TextColor3 = config.Marines.Value.TeamColor.Color
raids.TextColor3 = config.Officers.Value.TeamColor.Color

defs.Text = string.gsub(defFormat, '/N/', tostring(Marines))
raids.Text = string.gsub(raidFormat, '/N/', tostring(Officers))

local defs = config.Marines.Value:GetPlayers()
defsChanged(#defs)

local raids = config.Officers.Value:GetPlayers()
raidsChanged(#raids)

config.Marines.Value.PlayerAdded:Connect(function()
	defsChanged(1)
end)
config.Marines.Value.PlayerRemoved:Connect(function()
	defsChanged(-1)
end)

config.Officers.Value.PlayerAdded:Connect(function()
	raidsChanged(1)
end)
config.Officers.Value.PlayerRemoved:Connect(function()
	raidsChanged(-1)
end)