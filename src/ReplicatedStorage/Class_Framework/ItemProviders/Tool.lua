local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Access = require(ReplicatedStorage:WaitForChild("Class_Access"))
local Types = require(Access.Framework:WaitForChild("Types"))
local AssetPath
local ToolProvider: Types.IClassItem = {
    Identifier = "Tool",
    AssignType = Access.Enums.AssignType.PerCharacter,
}

function ToolProvider.GetItem(itemName: string)
    local assetPath = AssetPath or Access.Config.ItemTypePaths[ToolProvider.Identifier]
    assert(assetPath, `asset path not found for ItemType {script.Name} - a folder of name {ToolProvider.Identifier} must be linked within the config`)

    return assetPath:FindFirstChild(itemName)
end

function ToolProvider.Assign(player: Player, itemName: string, amount: number)
    local item = ToolProvider.GetItem(itemName)
    if not item then
        warn(`item {itemName} not found for ItemType {script.Name}`)
        return
    end
    local itemInstance = item:Clone()
    itemInstance.Parent = player.Backpack
end

function ToolProvider.Unassign(player: Player, itemName: string, amount: number)
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
    end
end

return ToolProvider