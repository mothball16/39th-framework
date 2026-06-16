local Types = require("../Core/Types")
local Enums = require("../Core/Enums")

local ORIG_MAX_HEALTH_ATTR = "OriginalMaxHealth"

local MaxHealthProvider: Types.ClassItemProvider<BuildArgs> = {
    ID = "MaxHealth",
    AssignType = Enums.AssignType.PerCharacter,
}

export type BuildArgs = {
    value: number,
    name: string?,
}
export type ItemArgs = { type: "MaxHealth" } & BuildArgs

function MaxHealthProvider.Build(args: BuildArgs): ItemArgs
    return {
        type = MaxHealthProvider.ID,
        value = args.value,
        name = args.name,
    }
end

local function getHumanoid(player: Player): Humanoid?
    local character = player.Character
    if not character then
        warn("character not found")
        return nil
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        warn("humanoid not found")
        return nil
    end

    return humanoid
end

function MaxHealthProvider.Assign(player: Player, args: ItemArgs)
    local humanoid = getHumanoid(player)
    if not humanoid then
        return
    end

    if not humanoid:GetAttribute(ORIG_MAX_HEALTH_ATTR) then
        humanoid:SetAttribute(ORIG_MAX_HEALTH_ATTR, humanoid.MaxHealth)
    end

    humanoid.MaxHealth = args.value
    humanoid.Health = math.min(humanoid.Health, humanoid.MaxHealth)
end

function MaxHealthProvider.Unassign(player: Player, args: ItemArgs)
    local humanoid = getHumanoid(player)
    if not humanoid then
        return
    end

    local originalMaxHealth = humanoid:GetAttribute(ORIG_MAX_HEALTH_ATTR)
    if originalMaxHealth then
        humanoid.MaxHealth = originalMaxHealth
        humanoid.Health = math.min(humanoid.Health, humanoid.MaxHealth)
        humanoid:SetAttribute(ORIG_MAX_HEALTH_ATTR, nil)
    end
end

return MaxHealthProvider
