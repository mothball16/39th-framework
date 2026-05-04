local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local ConfigurationTypes = require(ReplicatedStorage.SPH_Framework.Core.ConfigurationTypes)
local TAG_NAME = "SPH_Assets"

local _assetPaths = CollectionService:GetTagged(TAG_NAME)
local AssetPath = _assetPaths[1]

if not AssetPath then
	error(`{TAG_NAME} tag not found - tag your assets folder with {TAG_NAME}`)
elseif #_assetPaths > 1 then
	warn(`{TAG_NAME} tag found {#_assetPaths} times - tag only one assets folder with {TAG_NAME}.`)
end

local access = table.freeze({
	assets = AssetPath,
	framework = ReplicatedStorage:WaitForChild("SPH_Framework"),
	config = require(AssetPath:WaitForChild("GameConfig")) :: ConfigurationTypes.MainGameSettings,
	enums = require(ReplicatedStorage.SPH_Framework:WaitForChild("Core"):WaitForChild("Enums"))
})

return access