local Access = require("../Access")
local Types = require("../Core/Types")
local Enums = require("../Core/Enums")

local ATTR_LIMB_NAME = "AccessoryLimbName"

local AccessoryProvider: Types.ClassItemProvider<BuildArgs> = {
    ID = "Accessory",
    AssignType = Enums.AssignType.PerCharacter,
}


export type BuildArgs = {
    itemName: string,
    limbName: string?,
}
export type ItemArgs = { itemType: "Accessory" } & BuildArgs

function AccessoryProvider.Build(itemArgs: BuildArgs): ItemArgs
    return {
        itemType = AccessoryProvider.ID,
        itemName = itemArgs.itemName,
        limbName = itemArgs.limbName,
    }
end

function AccessoryProvider.GetItem(itemName: string)
    local assetPath = Access.Config.ItemTypePaths[AccessoryProvider.ID]
    assert(assetPath, `asset path not found for ItemType {script.Name} - a folder of name {AccessoryProvider.ID} must be linked within the config`)

    local item = assetPath:FindFirstChild(itemName)
    if not item then
        return nil
    end
    if not item:IsA("Accessory") then
        warn(`item {itemName} found for ItemType {script.Name} but it is not an Accessory`)
        return nil
    end
    return item
end

local function _tagAccessory(accessory: Accessory, itemName: string, limbName: string?)
    accessory:SetAttribute(Enums.KeyAttributes.ItemProvider, AccessoryProvider.ID)
    accessory:SetAttribute(Enums.KeyAttributes.ItemName, itemName)
    if limbName then
        accessory:SetAttribute(ATTR_LIMB_NAME, limbName)
    else
        accessory:SetAttribute(ATTR_LIMB_NAME, nil)
    end
end

local function _attachToLimb(character: Model, accessory: Accessory, limbName: string): boolean
    local limb = character:FindFirstChild(limbName)
    if not limb or not limb:IsA("BasePart") then
        warn(`limb {limbName} not found on character for accessory {accessory.Name}`)
        return false
    end

    local handle = accessory:FindFirstChild("Handle")
    if not handle or not handle:IsA("BasePart") then
        warn(`accessory {accessory.Name} has no BasePart Handle`)
        return false
    end

    local weld = handle:FindFirstChild("AccessoryWeld")
    if weld and weld:IsA("Weld") then
        weld.Part1 = limb
        return true
    end

    local weldConstraint = Instance.new("WeldConstraint")
    weldConstraint.Part0 = handle
    weldConstraint.Part1 = limb
    weldConstraint.Parent = handle
    handle.CFrame = limb.CFrame
    return true
end

function AccessoryProvider.Assign(player: Player, itemArgs: ItemArgs)
    local character = player.Character
    if not character then
        warn("character not found")
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        warn("humanoid not found")
        return
    end

    local itemName = itemArgs.itemName
    if not itemName then
        warn("accessory item name not found in item args")
        return
    end

    local template = AccessoryProvider.GetItem(itemName)
    if not template then
        warn(`item {itemName} not found for ItemType {script.Name}`)
        return
    end

    local limbName = itemArgs.limbName
    local accessory = template:Clone()
    _tagAccessory(accessory, itemName, limbName)
    humanoid:AddAccessory(accessory)

    if limbName then
        local attached = _attachToLimb(character, accessory, limbName)
        if not attached then
            accessory:Destroy()
        end
    end
end

function AccessoryProvider.Unassign(player: Player, itemArgs: ItemArgs)
    local character = player.Character
    if not character then
        warn("character not found")
        return
    end

    local itemName = itemArgs.itemName
    if not itemName then
        warn("accessory item name not found in item args")
        return
    end

    local limbName = itemArgs.limbName

    for _, child in ipairs(character:GetChildren()) do
        if not child:IsA("Accessory") or child.Name ~= itemName then
            continue
        end

        local provider = child:GetAttribute(Enums.KeyAttributes.ItemProvider)
        local taggedItemName = child:GetAttribute(Enums.KeyAttributes.ItemName)
        local taggedLimbName = child:GetAttribute(ATTR_LIMB_NAME)
        if provider ~= AccessoryProvider.ID or taggedItemName ~= itemName then
            continue
        end
        if limbName and taggedLimbName ~= limbName then
            continue
        end

        child:Destroy()
    end
end

return AccessoryProvider
