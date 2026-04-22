local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AssetPath = ReplicatedStorage:WaitForChild("SPH_Assets")
local ConfigurationTypes = require(ReplicatedStorage.SPH_Framework.Core.ConfigurationTypes)

local access = table.freeze({
	assets = AssetPath,
	framework = ReplicatedStorage:WaitForChild("SPH_Framework"),
	config = require(AssetPath:WaitForChild("GameConfig")) :: ConfigurationTypes.MainGameSettings,
	enums = require(ReplicatedStorage.SPH_Framework:WaitForChild("Core"):WaitForChild("Enums"))
})

return access
