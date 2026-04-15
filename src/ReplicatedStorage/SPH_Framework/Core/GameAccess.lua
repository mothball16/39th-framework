--!strict
--[[
	Single entry for SPH_Assets root, SPH_Framework root, and typed GameConfig.
	Require once per VM; results are cached by Luau's require.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigurationTypes = require(script.Parent.ConfigurationTypes)

export type MainGameSettings = ConfigurationTypes.MainGameSettings

export type GameAccess = {
	assets: Folder,
	framework: Folder,
	config: MainGameSettings,
}

local assets = ReplicatedStorage:WaitForChild("SPH_Assets") :: Folder
local framework = ReplicatedStorage:WaitForChild("SPH_Framework") :: Folder
-- Cast: Roblox LSP may not resolve ConfigurationTypes.MainGameSettings when that module returns nil.
local config = require(assets:WaitForChild("GameConfig")) :: ConfigurationTypes.MainGameSettings

local access: GameAccess = table.freeze({
	assets = assets,
	framework = framework,
	config = config,
})

return access
