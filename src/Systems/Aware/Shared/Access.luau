local CollectionService = game:GetService("CollectionService")
local Types = require("./Core/Types")

local function resolveSingleTaggedAsset(tagName: string): Instance
	local asset = CollectionService:GetTagged(tagName)
	if #asset == 0 then
		CollectionService:GetInstanceAddedSignal(tagName):Wait(5)
		asset = CollectionService:GetTagged(tagName)
	end

	if #asset == 0 then
		error(`{tagName} tag not found after 5s - tag your assets folder with {tagName}`)
	end
	if #asset > 1 then
		warn(`{tagName} tag found {#asset} times - tag only one assets folder with {tagName}.`)
	end
	return asset[1]
end

export type Access = {
	assets: Instance,
	config: Types.GameSettings,
}

local access: Access = table.freeze({
	assets = resolveSingleTaggedAsset("Aware_Assets"),
	config = require(resolveSingleTaggedAsset("Aware_GameConfig")),
})

return access
