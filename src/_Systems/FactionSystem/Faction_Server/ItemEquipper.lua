local Maid = require("@game/ReplicatedStorage/Packages/maid")
local Types = require("@game/ReplicatedStorage/Faction_Framework/Core/Types")

local ItemEquipper = {}
ItemEquipper.__index = ItemEquipper

--[[
logic class for setting up and providing items of all loaded itemtypes to players/characters
]]
type self = {
	_maid: Maid.Maid,
	_itemProviders: { [string]: Types.ClassItemProvider },
	_classes: { [string]: Types.Class },
}
export type ItemEquipper = typeof(setmetatable({} :: self, ItemEquipper))


function ItemEquipper.new(itemProviders: { [string]: Types.ClassItemProvider }, classes: { [string]: Types.Class }): ItemEquipper
	local self = setmetatable({
		_itemProviders = itemProviders,
		_maid = Maid.new(),
		_classes = classes,
	} :: self, ItemEquipper)

	return self
end

function ItemEquipper.GetProvider(self: ItemEquipper, itemArgs: any): Types.ClassItemProvider
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

function ItemEquipper.AssignClassItems(self: ItemEquipper, player: Player, classId: string)
	local classConfig = self._classes[classId]
	if not classConfig then
		warn(`class config not found for class {classId}`)
		return
	end

	self:UnassignClassItems(player, classId)

	for _, itemArgs in ipairs(classConfig.Items) do
		local itemProvider = self:GetProvider(itemArgs)
		if itemProvider then
			itemProvider.Assign(player, itemArgs)
		end
	end
end

function ItemEquipper.UnassignClassItems(self: ItemEquipper, player: Player, classId: string)
	local classConfig = self._classes[classId]
	if not classConfig then
		warn(`class config not found for class {classId}`)
		return
	end

	for _, itemArgs in ipairs(classConfig.Items) do
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
