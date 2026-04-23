local Atoms = require(script.Parent.Atoms)
local Events = require(script.Parent.Events)

export type Atoms = typeof(Atoms)
export type Events = typeof(Events)

export type IClassItem = {
    -- identifier for item type within configurations
    Identifier: string,
    -- runs when the class containing the item is assigned to a player
    Assign: (player: Player) -> (),
    -- runs when the class containing the item is unassigned from a player
    Unassign: (player: Player) -> ()
}

return {}