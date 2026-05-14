local CollectionService = game:GetService("CollectionService")
local ConfigurationTypes = require(script.Parent.Core.ConfigurationTypes)
local TAG_NAME = "SPH_Assets"

local _assetPaths = CollectionService:GetTagged(TAG_NAME)
local AssetPath = _assetPaths[1]

if not AssetPath then
	error(`{TAG_NAME} tag not found - tag your assets folder with {TAG_NAME}`)
elseif #_assetPaths > 1 then
	warn(`{TAG_NAME} tag found {#_assetPaths} times - tag only one assets folder with {TAG_NAME}.`)
end

local gameConfigModule = AssetPath:FindFirstChild("GameConfig")
if not gameConfigModule or not gameConfigModule:IsA("ModuleScript") then
	error(`GameConfig ModuleScript missing under tagged assets folder ({TAG_NAME})`)
end

local access = table.freeze({
	assets = AssetPath,
	config = require(gameConfigModule) :: ConfigurationTypes.MainGameSettings,
})

return access