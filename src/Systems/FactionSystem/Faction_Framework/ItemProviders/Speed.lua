local Types = require("../Core/Types")
local Enums = require("../Core/Enums")

local ORIG_WALK_SPEED_ATTR = "OriginalWalkSpeed"

local SpeedProvider: Types.ClassItemProvider<BuildArgs> = {
    ID = "Speed",
    AssignType = Enums.AssignType.PerCharacter,
}

export type BuildArgs = {
    value: number,
    name: string?,
}
export type ItemArgs = { type: "Speed" } & BuildArgs

function SpeedProvider.Build(args: BuildArgs): ItemArgs
    return {
        type = SpeedProvider.ID,
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

function SpeedProvider.Assign(player: Player, args: ItemArgs)
    local humanoid = getHumanoid(player)
    if not humanoid then
        return
    end

    if not humanoid:GetAttribute(ORIG_WALK_SPEED_ATTR) then
        humanoid:SetAttribute(ORIG_WALK_SPEED_ATTR, humanoid.WalkSpeed)
    end

    humanoid.WalkSpeed = args.value
end

function SpeedProvider.Unassign(player: Player, args: ItemArgs)
    local humanoid = getHumanoid(player)
    if not humanoid then
        return
    end

    local originalWalkSpeed = humanoid:GetAttribute(ORIG_WALK_SPEED_ATTR)
    if originalWalkSpeed then
        humanoid.WalkSpeed = originalWalkSpeed
        humanoid:SetAttribute(ORIG_WALK_SPEED_ATTR, nil)
    end
end

return SpeedProvider
