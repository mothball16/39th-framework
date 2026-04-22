local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ConfigurationTypes = require(script.Parent.ConfigurationTypes)
local AssetPath = ReplicatedStorage:WaitForChild("SPH_Assets")

local access = table.freeze({
	assets = AssetPath,
	framework = ReplicatedStorage:WaitForChild("SPH_Framework"),
	config = require(AssetPath:WaitForChild("GameConfig")) :: ConfigurationTypes.MainGameSettings,
	enums = require(ReplicatedStorage.SPH_Framework:WaitForChild("Core"):WaitForChild("Enums"))
})

return access
