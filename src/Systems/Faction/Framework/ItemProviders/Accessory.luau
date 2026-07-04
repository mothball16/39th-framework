local Access = require("../Access")
local Types = require("../Core/Types")
local Enums = require("../Core/Enums")

local ATTR_LIMB_NAME = "AccessoryLimbName"

local AccessoryProvider: Types.VariantItemProvider<BuildArgs> = {
    ID = "Accessory",
    AssignType = Enums.AssignType.PerCharacter,
}


export type BuildArgs = {
    name: string,
    limbName: string?,
}
export type ItemArgs = { type: "Accessory" } & BuildArgs

function AccessoryProvider.Build(args: BuildArgs): ItemArgs
    return {
        type = AccessoryProvider.ID,
        name = args.name,
        limbName = args.limbName or "Head",
    }
end

function AccessoryProvider.GetItem(name: string)
    local assetPath = Access.Config.ItemTypePaths[AccessoryProvider.ID]
    assert(assetPath, `asset path not found for ItemType {script.Name} - a folder of name {AccessoryProvider.ID} must be linked within the config`)

    local item = assetPath:FindFirstChild(name)
    if not item then
        return nil
    end
    if not item:IsA("Accessory") then
        warn(`accessory {name} found for ItemType {script.Name} but it is not an Accessory`)
        return nil
    end
    return item
end

local function _tagAccessory(accessory: Accessory, name: string, limbName: string?)
    accessory:SetAttribute(Enums.KeyAttributes.ItemProvider, AccessoryProvider.ID)
    accessory:SetAttribute(Enums.KeyAttributes.ItemName, name)
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

function AccessoryProvider.Assign(player: Player, args: ItemArgs)
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

    local name = args.name
    if not name then
        warn("accessory name not found in args")
        return
    end

    local template = AccessoryProvider.GetItem(name)
    if not template then
        warn(`accessory {name} not found for ItemType {script.Name}`)
        return
    end

    local limbName = args.limbName
    local accessory = template:Clone()
    _tagAccessory(accessory, name, limbName)
    humanoid:AddAccessory(accessory)

    if limbName then
        local attached = _attachToLimb(character, accessory, limbName)
        if not attached then
            accessory:Destroy()
        end
    end
end

function AccessoryProvider.Unassign(player: Player, args: ItemArgs)
    local character = player.Character
    if not character then
        warn("character not found")
        return
    end

    local name = args.name
    if not name then
        warn("accessory name not found in args")
        return
    end

    local limbName = args.limbName

    for _, child in ipairs(character:GetChildren()) do
        if not child:IsA("Accessory") or child.Name ~= name then
            continue
        end

        local provider = child:GetAttribute(Enums.KeyAttributes.ItemProvider)
        local taggedName = child:GetAttribute(Enums.KeyAttributes.ItemName)
        local taggedLimbName = child:GetAttribute(ATTR_LIMB_NAME)
        if provider ~= AccessoryProvider.ID or taggedName ~= name then
            continue
        end
        if limbName and taggedLimbName ~= limbName then
            continue
        end

        child:Destroy()
    end
end

return AccessoryProvider
