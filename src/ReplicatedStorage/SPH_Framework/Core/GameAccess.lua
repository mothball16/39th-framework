--!strict
--[[
	Single entry for SPH_Assets root, SPH_Framework root, and typed GameConfig.
	Require once per VM; results are cached by Luau's require.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigurationTypes = require(script.Parent.ConfigurationTypes)


local access = table.freeze({
	assets = ReplicatedStorage:WaitForChild("SPH_Assets"),
	framework = ReplicatedStorage:WaitForChild("SPH_Framework"),
	config = require(ReplicatedStorage.SPH_Assets:WaitForChild("GameConfig")) :: ConfigurationTypes.MainGameSettings,
})

return access
