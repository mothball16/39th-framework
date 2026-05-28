local Types = require("../Core/Types")
local Enums = require("../Core/Enums")
local TestProvider: Types.ClassItemProvider = {
    ID = "Test",
    AssignType = Enums.AssignType.PerCharacter,
}

export type ItemArgs = {
    itemType: "Test",
    itemName: string,
}

function TestProvider.Assign(player: Player, itemArgs: ItemArgs)
    print(`{player.UserId} assigned to {TestProvider.ID} with args:`)
    print(itemArgs)
end

function TestProvider.Unassign(player: Player, itemArgs: ItemArgs)
    print(`{player.UserId} unassigned from {TestProvider.ID} with args:`)
    print(itemArgs)
end

return TestProvider