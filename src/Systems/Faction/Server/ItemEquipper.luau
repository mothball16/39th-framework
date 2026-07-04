local Maid = require("@game/ReplicatedStorage/Packages/maid")
local Types = require("@game/ReplicatedStorage/Systems/Faction/Core/Types")

local ItemEquipper = {}
ItemEquipper.__index = ItemEquipper

--[[
logic class for setting up and providing items of all loaded itemtypes to players/characters
]]
type self = {
	_maid: Maid.Maid,
	_itemProviders: { [string]: Types.VariantItemProvider },
	_variants: { [string]: Types.Variant },
}
export type ItemEquipper = typeof(setmetatable({} :: self, ItemEquipper))


function ItemEquipper.new(itemProviders: { [string]: Types.VariantItemProvider }, variants: { [string]: Types.Variant }): ItemEquipper
	local self = setmetatable({
		_itemProviders = itemProviders,
		_maid = Maid.new(),
		_variants = variants,
	} :: self, ItemEquipper)

	return self
end

function ItemEquipper.GetProvider(self: ItemEquipper, itemArgs: any): Types.VariantItemProvider
	local itemType = itemArgs.type or itemArgs.itemType or itemArgs.ItemType or itemArgs.Type
	if not itemType then
		warn(`type not found for item args {itemArgs}`)
		return nil
	end

	local itemProvider = self._itemProviders[itemType]
	if not itemProvider then
		warn(`item provider not found for item type {itemType}`)
		return nil
	end
	return itemProvider
end

function ItemEquipper.AssignVariantItems(self: ItemEquipper, player: Player, variantId: string)
	local variantConfig = self._variants[variantId]
	if not variantConfig then
		warn(`variant config not found for variant {variantId}`)
		return
	end

	self:UnassignVariantItems(player, variantId)

	for _, itemArgs in ipairs(variantConfig.Items) do
		local itemProvider = self:GetProvider(itemArgs)
		if itemProvider then
			itemProvider.Assign(player, itemArgs)
		end
	end
end

function ItemEquipper.UnassignVariantItems(self: ItemEquipper, player: Player, variantId: string)
	local variantConfig = self._variants[variantId]
	if not variantConfig then
		warn(`variant config not found for variant {variantId}`)
		return
	end

	for _, itemArgs in ipairs(variantConfig.Items) do
		local itemProvider = self:GetProvider(itemArgs)
		if itemProvider then
			itemProvider.Unassign(player, itemArgs)
		end
	end
end

function ItemEquipper:Destroy()
	self._maid:DoCleaning()
end

return ItemEquipper
