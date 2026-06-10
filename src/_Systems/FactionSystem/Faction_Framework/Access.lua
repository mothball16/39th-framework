--[[
resolves asset paths and provides config without having to typecast in every script that uses the config
this helps reduce the amount of boilerplate that has to be put up top in every script
]]

local CollectionService = game:GetService("CollectionService")
local Types = require("./Core/Types")
local TAG_NAME = "Faction_Assets"

local _assetPaths = CollectionService:GetTagged(TAG_NAME)
local AssetPath = _assetPaths[1]

if not AssetPath then
	error(`{TAG_NAME} tag not found - tag your assets folder with {TAG_NAME}`)
elseif #_assetPaths > 1 then
	warn(`{TAG_NAME} tag found {#_assetPaths} times - tag only one assets folder with {TAG_NAME}.`)
end


local access: Types.Access = table.freeze({
	Assets = AssetPath,
	Config = require(AssetPath:WaitForChild("GameConfig")) :: Types.Settings,
})

return access
