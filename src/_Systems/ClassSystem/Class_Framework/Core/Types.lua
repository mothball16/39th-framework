local Vide = require("@game/ReplicatedStorage/Packages/Vide")
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
    AfterTeamChangeBehavior: string,
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

export type Class = {
    ID: string,
    Items: {any}
}

export type InteractionController = {
    isOpen: Vide.Source<boolean>,
    Initialize: (isOpen: Vide.Source<boolean>) -> (),
    Destroy: () -> (),
}

return Types