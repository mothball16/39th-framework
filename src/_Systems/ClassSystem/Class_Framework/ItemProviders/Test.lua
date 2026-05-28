local Types = require("../Core/Types")
local Enums = require("../Core/Enums")
local TestProvider: Types.ClassItemProvider<BuildArgs> = {
    ID = "Test",
    AssignType = Enums.AssignType.PerCharacter,
}


export type BuildArgs = {
    name: string?,
}
export type ItemArgs = { type: "Test" } & BuildArgs


function TestProvider.Build(args: BuildArgs): ItemArgs
    return {
        type = TestProvider.ID,
        name = args.name or "Test",
    }
end

function TestProvider.Assign(player: Player, args: ItemArgs)
    print(`{player.UserId} assigned to {TestProvider.ID} with args:`)
    print(args)
end

function TestProvider.Unassign(player: Player, args: ItemArgs)
    print(`{player.UserId} unassigned from {TestProvider.ID} with args:`)
    print(args)
end

return TestProvider
