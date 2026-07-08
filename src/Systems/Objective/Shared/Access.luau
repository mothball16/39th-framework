--!strict
--#selene: allow(incorrect_standard_library_use)
local CollectionService = game:GetService("CollectionService")

local Types = require("./Core/Types")

local TAG_NAME = "Objective_Assets"
local taggedAssets = CollectionService:GetTagged(TAG_NAME)
local assetPath = taggedAssets[1]

if not assetPath then
	error(`{TAG_NAME} tag not found - tag your objective assets folder with {TAG_NAME}`)
elseif #taggedAssets > 1 then
	warn(`{TAG_NAME} tag found {#taggedAssets} times - tag only one objective assets folder with {TAG_NAME}.`)
end

local configModule = assetPath:FindFirstChild("GameConfig")
local config = if configModule and configModule:IsA("ModuleScript") then require(configModule) else {}

local access: Types.Access = table.freeze({
	Assets = assetPath :: Folder,
	Config = config :: Types.Settings,
})

return access
