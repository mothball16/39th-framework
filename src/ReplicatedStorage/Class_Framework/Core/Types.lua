local Events = require(script.Parent.Events)

local Types = {}

export type Events = typeof(Events)

export type ClassItemProvider = {
    -- identifier for item type within configurations
    ID: string,
    AssignType: string?,
    -- runs when the class containing the item is assigned to a player
    Assign: (player: Player, itemArgs: any) -> (),
    -- runs when the class containing the item is unassigned from a player
    Unassign: (player: Player, itemArgs: any) -> ()
}

export type Settings = {
    ItemTypePaths: {
        [string]: Folder,
    },
}

export type FactionConfig = {
    ID: string,
    Classes: {
        [string]: {ClassID: string, Limit: number, Default: boolean}
    },
}

export type PlayerClassAssignment = {
    FactionId: string,
    ClassId: string,
}

export type FactionState = {
    Members: {
        [string]: {
            Class: string
        }
    }
}

export type Faction = {
    Config: FactionConfig,
    State: FactionState,
}

export type Class = {
    ID: string,
    Items: {any}
}

return Types