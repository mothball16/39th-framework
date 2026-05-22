local Access = require("../Access")
local Types = require("../Core/Types")
local Enums = require("../Core/Enums")
local ToolProvider: Types.ClassItemProvider = {
    ID = "Tool",
    AssignType = Enums.AssignType.PerCharacter,
}

local function _resolveItemAmount(itemArgs: any): number
	return itemArgs.amount or 1
end

function ToolProvider.GetItem(itemName: string)
    local assetPath = Access.Config.ItemTypePaths[ToolProvider.ID]
    assert(assetPath, `asset path not found for ItemType {script.Name} - a folder of name {ToolProvider.ID} must be linked within the config`)

    return assetPath:FindFirstChild(itemName)
end

function ToolProvider.Assign(player: Player, itemArgs: any)
    local itemName = itemArgs.itemName
    if not itemName then
        warn("tool item name not found in item args")
        return
    end

    local item = ToolProvider.GetItem(itemName)
    if not item then
        warn(`item {itemName} not found for ItemType {script.Name}`)
        return
    end
    local amount = _resolveItemAmount(itemArgs)
    local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack")
    for _ = 1, amount do
        local itemInstance = item:Clone()
        itemInstance:SetAttribute(Enums.KeyAttributes.ItemProvider, ToolProvider.ID)
        itemInstance:SetAttribute(Enums.KeyAttributes.ItemName, itemName)
        itemInstance.Parent = backpack
    end
end

function ToolProvider.Unassign(player: Player, itemArgs: any)
    local itemName = itemArgs.itemName
    if not itemName then
        warn("tool item name not found in item args")
        return
    end

    local remaining = _resolveItemAmount(itemArgs)

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

            local provider = child:GetAttribute(Enums.KeyAttributes.ItemProvider)
            local taggedItemName = child:GetAttribute(Enums.KeyAttributes.ItemName)
            if provider ~= ToolProvider.ID or taggedItemName ~= itemName then
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