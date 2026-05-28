local Access = require("../Access")
local Types = require("../Core/Types")
local Enums = require("../Core/Enums")
local ToolProvider: Types.ClassItemProvider<BuildArgs> = {
    ID = "Tool",
    AssignType = Enums.AssignType.PerCharacter,
}


export type BuildArgs = {
    name: string,
    amount: number?,
}
export type ItemArgs = { type: "Tool" } & BuildArgs


function ToolProvider.Build(args: BuildArgs): ItemArgs
    return {
        type = ToolProvider.ID,
        name = args.name,
        amount = args.amount or 1,
    }
end


function ToolProvider.GetItem(name: string)
    local assetPath = Access.Config.ItemTypePaths[ToolProvider.ID]
    assert(assetPath, `asset path not found for ItemType {script.Name} - a folder of name {ToolProvider.ID} must be linked within the config`)

    return assetPath:FindFirstChild(name)
end

function ToolProvider.Assign(player: Player, args: ItemArgs)
    local name = args.name
    if not name then
        warn("tool name not found in args")
        return
    end

    local item = ToolProvider.GetItem(name)
    if not item then
        warn(`tool {name} not found for ItemType {script.Name}`)
        return
    end
    local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack")
    for _ = 1, args.amount do
        local itemInstance = item:Clone()
        itemInstance:SetAttribute(Enums.KeyAttributes.ItemProvider, ToolProvider.ID)
        itemInstance:SetAttribute(Enums.KeyAttributes.ItemName, name)
        itemInstance.Parent = backpack
    end
end

function ToolProvider.Unassign(player: Player, args: ItemArgs)
    local name = args.name
    if not name then
        warn("tool name not found in args")
        return
    end

    local remaining = args.amount

    local function tryRemoveFrom(container: Instance?)
        if not container or remaining <= 0 then
            return
        end

        for _, child in ipairs(container:GetChildren()) do
            if remaining <= 0 then
                break
            end
            if not child:IsA("Tool") or child.Name ~= name then
                continue
            end

            local provider = child:GetAttribute(Enums.KeyAttributes.ItemProvider)
            local taggedName = child:GetAttribute(Enums.KeyAttributes.ItemName)
            if provider ~= ToolProvider.ID or taggedName ~= name then
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
