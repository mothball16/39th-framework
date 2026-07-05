local CollectionService = game:GetService("CollectionService")
local ConfigurationTypes = require(script.Parent.Core.ConfigurationTypes)



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

local access = table.freeze({
	assets = resolveSingleTaggedAsset("SPH_Assets"),
	config = require(resolveSingleTaggedAsset("SPH_GameConfig")) :: ConfigurationTypes.MainGameSettings,
})

return access