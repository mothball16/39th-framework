local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Access = require(ReplicatedStorage:WaitForChild("Class_Access"))
local Types = require(Access.Framework.Core:WaitForChild("Types"))
local Enums = require(Access.Framework.Core:WaitForChild("Enums"))
local ToolProvider: Types.IClassItemProvider = {
    ID = "Tool",
    AssignType = Enums.AssignType.PerCharacter,
}

function ToolProvider.GetItem(itemName: string)
    local assetPath = Access.Config.ItemTypePaths[ToolProvider.ID]
    assert(assetPath, `asset path not found for ItemType {script.Name} - a folder of name {ToolProvider.ID} must be linked within the config`)

    return assetPath:FindFirstChild(itemName)
end

function ToolProvider.Assign(player: Player, itemArgs: any)
    local itemName = itemArgs.itemName or itemArgs.ItemName or itemArgs.ID or itemArgs.Name
    if not itemName then
        warn("tool item name not found in item args")
        return
    end

    local item = ToolProvider.GetItem(itemName)
    if not item then
        warn(`item {itemName} not found for ItemType {script.Name}`)
        return
    end
    local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack")
    local itemInstance = item:Clone()
    itemInstance.Parent = backpack
end

function ToolProvider.Unassign(player: Player, itemArgs: any)
    -- holding off on this for now - it seems safer to just respawn the character

    --[[
    -- unequip tool so item deletion logic isnt wonky
    local character = player.Character
    if character then
        local tool = character:FindFirstChildWhichIsA("Tool")
        if tool then
            tool.Parent = player.Backpack
        end
    end

    -- remove appropriate amount of items from backpack
    while amount > 0 do
        local itemInstance = player.Backpack:FindFirstChild(itemName)
        if itemInstance then
            itemInstance:Destroy()
            amount -= 1
        else
            break
        end
    end]]
end

return ToolProvider