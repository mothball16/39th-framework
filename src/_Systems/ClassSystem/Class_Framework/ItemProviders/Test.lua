local Types = require("../Core/Types")
local Enums = require("../Core/Enums")
local TestProvider: Types.ClassItemProvider<BuildArgs> = {
    ID = "Test",
    AssignType = Enums.AssignType.PerCharacter,
}


export type BuildArgs = {
    itemName: string,
}
export type ItemArgs = { itemType: "Test" } & BuildArgs


function TestProvider.Build(itemArgs: BuildArgs): ItemArgs
    return {
        itemType = TestProvider.ID,
        itemName = itemArgs.itemName,
    }
end

function TestProvider.Assign(player: Player, itemArgs: ItemArgs)
    print(`{player.UserId} assigned to {TestProvider.ID} with args:`)
    print(itemArgs)
end

function TestProvider.Unassign(player: Player, itemArgs: ItemArgs)
    print(`{player.UserId} unassigned from {TestProvider.ID} with args:`)
    print(itemArgs)
end

return TestProvider