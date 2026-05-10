local Types = {}


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
    ApplyClassMode: string,
    ItemTypePaths: {
        [string]: Folder,
    },

    DebugMode: boolean,
}

export type ClassVariant = {
    Id: string,
    Name: string?,
    Description: string?,
}

export type FactionConfig = {
    ID: string,
    Name: string,
    Classes: {
        [string]: ClassConfig,
    },
    DefaultClassKey: string?,
}

export type ClassConfig = {
    ClassIDs: {ClassVariant},
    Limit: number,
    Default: boolean,
}

export type PlayerClassAssignment = {
    FactionId: string,
    ClassKey: string,
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