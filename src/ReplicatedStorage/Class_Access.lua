local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Framework = ReplicatedStorage:WaitForChild("Class_Framework")
local Types = require(Framework:WaitForChild("Types"))
local AssetPath = script:GetAttribute("AssetPath") or ReplicatedStorage:WaitForChild("Class_Assets")

--[[
resolves asset paths and provides config without having to typecast in every script that uses the config
this helps reduce the amount of boilerplate that has to be put up top in every script
]]

local access = table.freeze({
	Assets = AssetPath,
	Framework = Framework,
	Packages = Packages,
	Enums = require(Framework:WaitForChild("Enums")),
	Config = require(AssetPath:WaitForChild("GameConfig")) :: Types.ISettings,
})

return access
