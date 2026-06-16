local Access = require("../Access")
local Types = require("../Core/Types")
local Enums = require("../Core/Enums")

local ORIG_CLOTHING_ATTR = "OriginalClothing"

local PROPERTY_BY_TYPE = {
    Shirt = "ShirtTemplate",
    Pants = "PantsTemplate",
    ShirtGraphic = "Graphic",
}

local UniformProvider: Types.ClassItemProvider<BuildArgs> = {
    ID = "Uniform",
    AssignType = Enums.AssignType.PerCharacter,
}

export type BuildArgs = {
    name: string,
}
export type ItemArgs = { type: "Uniform" } & BuildArgs


function UniformProvider.Build(args: BuildArgs): ItemArgs
    return {
        type = UniformProvider.ID,
        name = args.name,
    }
end

function UniformProvider.GetItem(name: string)
    local assetPath = Access.Config.ItemTypePaths[UniformProvider.ID]
    assert(assetPath, `asset path not found for ItemType {script.Name} - a folder of name {UniformProvider.ID} must be linked within the config`)
    local uniformPath = assetPath:FindFirstChild(name)
    if not uniformPath then
        warn(`uniform {name} not found for ItemType {script.Name}`)
        return nil
    end
    local shirt = uniformPath:FindFirstChildOfClass("Shirt")
    local pants = uniformPath:FindFirstChildOfClass("Pants")
    local tshirt = uniformPath:FindFirstChildOfClass("ShirtGraphic")

    return {
        Shirt = (if shirt then (shirt :: Shirt).ShirtTemplate else nil),
        Pants = (if pants then (pants :: Pants).PantsTemplate else nil),
        TShirt = (if tshirt then (tshirt :: ShirtGraphic).Graphic else nil),
    }
end

function UniformProvider.Assign(player: Player, args: ItemArgs)
    local character = player.Character
    if not character then
        warn("character not found")
        return
    end

    local name = args.name
    if not name then
        warn("uniform name not found in args")
        return
    end

    local item = UniformProvider.GetItem(name)
    if not item then
        warn(`uniform {name} not found for ItemType {script.Name}`)
        return
    end
    
    -- uniformprovider should retrieve the character's current shirt and pants and tshirt and assign them to the character.
    -- if the character doesn't have a shirt, pants, or tshirt, create the instance.
    -- in the case that the character does have a shirt, pants, or tshirt, just take the template from the item and assign it to the character.
    local function assignClothing(instanceType: "Shirt" | "Pants" | "ShirtGraphic", assetId: string)
        if not assetId then
            return
        end

        local clothing = character:FindFirstChildWhichIsA(instanceType)
        local clothingAssetProperty = PROPERTY_BY_TYPE[instanceType]

        if clothing and not clothing:GetAttribute(ORIG_CLOTHING_ATTR) then
            clothing:SetAttribute(ORIG_CLOTHING_ATTR, clothing[clothingAssetProperty])
        else
            clothing = Instance.new(instanceType)
            clothing.Parent = character
        end

        clothing[clothingAssetProperty] = assetId
    end
    assignClothing("Shirt", item.Shirt)
    assignClothing("Pants", item.Pants)
    assignClothing("ShirtGraphic", item.TShirt)
end

function UniformProvider.Unassign(player: Player, args: ItemArgs)
    local character = player.Character
    if not character then
        warn("character not found")
        return
    end

    local name = args.name
    if not name then
        warn("uniform name not found in args")
        return
    end

    -- uniform provider should retrieve the attribute from the character's shirt to re-shirt them as their old shirt.
    -- if the attribute isn't found, then that means the character had no shirt to begin with - you can delete the shirt in this case.
    local function unassignClothing(instanceType: "Shirt" | "Pants" | "ShirtGraphic")
        local clothing = character:FindFirstChildWhichIsA(instanceType)
        local clothingAssetProperty = PROPERTY_BY_TYPE[instanceType]

        if clothing and clothing:GetAttribute(ORIG_CLOTHING_ATTR) then
            clothing[clothingAssetProperty] = clothing:GetAttribute(ORIG_CLOTHING_ATTR)
        elseif clothing then
            clothing:Destroy()
        end
    end
    unassignClothing("Shirt")
    unassignClothing("Pants")
    unassignClothing("ShirtGraphic")
end

return UniformProvider
