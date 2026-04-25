local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Access = require(ReplicatedStorage:WaitForChild("Class_Access"))
local Maid = require(Access.Packages.maid)
local Types = require(Access.Framework:WaitForChild("Core"):WaitForChild("Types"))

local ClassEquipper = {}
ClassEquipper.__index = ClassEquipper

--[[
logic class for setting up and providing items of all loaded itemtypes to players/characters
]]

function ClassEquipper.new(itemProviders: {[string]: Types.IClassItemProvider}, classes: {[string]: Types.IClass})
    local self = setmetatable({
        maid = Maid.new(),
        itemProviders = itemProviders,
        classes = classes,
    }, ClassEquipper)

    return self
end

function ClassEquipper:GetProvider(itemArgs: any): Types.IClassItemProvider
    local itemType = itemArgs.itemType or itemArgs.ItemType or itemArgs.Type
    if not itemType then
        warn(`item type not found for item args {itemArgs}`)
        return nil
    end
    local itemProvider = self.itemProviders[itemType]
    if not itemProvider then
        warn(`item provider not found for item type {itemType}`)
        return nil
    end
    return itemProvider
end

function ClassEquipper:AssignClassItems(player: Player, classId: string)
    local classConfig = self.classes[classId]
    if not classConfig then
        warn(`class config not found for class {classId}`)
        return
    end

    for _, itemArgs in ipairs(classConfig.Items) do
        local itemProvider = self:GetProvider(itemArgs)
        if itemProvider then
            itemProvider.Assign(player, itemArgs)
        end
    end
end

function ClassEquipper:UnassignClassItems(player: Player, classId: string)
    local classConfig = self.classes[classId]
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
return ClassEquipper
