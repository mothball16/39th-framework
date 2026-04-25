local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Access = require(ReplicatedStorage:WaitForChild("Class_Access"))
local Types = require(Access.Framework.Core:WaitForChild("Types"))
local Enums = require(Access.Framework.Core:WaitForChild("Enums"))
local ToolProvider: Types.IClassItemProvider = {
    ID = "Tool",
    AssignType = Enums.AssignType.PerCharacter,
}
local PROVIDER_ATTRIBUTE = "ClassProvider"
local ITEM_NAME_ATTRIBUTE = "ClassItemName"

local function resolveItemName(itemArgs: any): string?
	return itemArgs.itemName or itemArgs.ItemName or itemArgs.ID or itemArgs.Name
end

local function resolveItemAmount(itemArgs: any): number
	local amount = itemArgs.amount or itemArgs.Amount
	if typeof(amount) == "number" and amount > 0 then
		return math.floor(amount)
	end
	return 1
end

function ToolProvider.GetItem(itemName: string)
    local assetPath = Access.Config.ItemTypePaths[ToolProvider.ID]
    assert(assetPath, `asset path not found for ItemType {script.Name} - a folder of name {ToolProvider.ID} must be linked within the config`)

    return assetPath:FindFirstChild(itemName)
end

function ToolProvider.Assign(player: Player, itemArgs: any)
    local itemName = resolveItemName(itemArgs)
    if not itemName then
        warn("tool item name not found in item args")
        return
    end

    local item = ToolProvider.GetItem(itemName)
    if not item then
        warn(`item {itemName} not found for ItemType {script.Name}`)
        return
    end
    local amount = resolveItemAmount(itemArgs)
    local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack")
    for _ = 1, amount do
        local itemInstance = item:Clone()
        itemInstance:SetAttribute(PROVIDER_ATTRIBUTE, ToolProvider.ID)
        itemInstance:SetAttribute(ITEM_NAME_ATTRIBUTE, itemName)
        itemInstance.Parent = backpack
    end
end

function ToolProvider.Unassign(player: Player, itemArgs: any)
    local itemName = resolveItemName(itemArgs)
    if not itemName then
        warn("tool item name not found in item args")
        return
    end

    local remaining = resolveItemAmount(itemArgs)

    local function tryRemoveFrom(container: Instance?)
        if not container or remaining <= 0 then
            return
        end

        for _, child in ipairs(container:GetChildren()) do
            if remaining <= 0 then
                break
            end
            if not child:IsA("Tool") or child.Name ~= itemName then
                continue
            end

            local provider = child:GetAttribute(PROVIDER_ATTRIBUTE)
            local taggedItemName = child:GetAttribute(ITEM_NAME_ATTRIBUTE)
            if provider ~= nil and provider ~= ToolProvider.ID then
                continue
            end
            if taggedItemName ~= nil and taggedItemName ~= itemName then
                continue
            end

            child:Destroy()
            remaining -= 1
        end
    end

    -- remove equipped tools first, then backpack copies
    tryRemoveFrom(player.Character)
    tryRemoveFrom(player:FindFirstChildOfClass("Backpack"))
end

return ToolProvider