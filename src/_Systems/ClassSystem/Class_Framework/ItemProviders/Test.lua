local Types = require("../Core/Types")
local Enums = require("../Core/Enums")
local TestProvider: Types.ClassItemProvider = {
    ID = "Test",
    AssignType = Enums.AssignType.PerCharacter,
}
function TestProvider.Assign(player: Player, itemArgs: any)
    print(`{player.UserId} assigned {itemArgs} to {TestProvider.ID}`)
end

function TestProvider.Unassign(player: Player, itemArgs: any)
    print(`{player.UserId} unassigned {itemArgs} from {TestProvider.ID}`)
end

return TestProvider