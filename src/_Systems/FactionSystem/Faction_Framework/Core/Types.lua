local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local Types = {}


export type ClassItemProvider<TBuild = any> = {
    -- identifier for item type within configurations
    ID: string,
    AssignType: string?,
    -- constructs config-friendly item args for this provider
    Build: (args: TBuild) -> ({ type: string } & TBuild),
    -- runs when the class containing the item is assigned to a player
    Assign: (player: Player, args: { type: string } & TBuild) -> (),
    -- runs when the class containing the item is unassigned from a player
    Unassign: (player: Player, args: { type: string } & TBuild) -> (),
}

export type Settings = {
    ShowManualButton: boolean,
    ApplyClassMode: string,
    AfterTeamChangeBehavior: string,
    ItemTypePaths: {
        [string]: Folder,
    },

    DebugMode: boolean,
}

export type Access = {
    Assets: Folder,
    Config: Settings,
}

export type ClassDescriptor = {
    Id: string,
    Name: string?,
    Description: string?,
    AccessCheck: AccessCheck?,
}

export type AccessCheck = (userId: number) -> boolean

export type FactionConfig = {
    ID: string,
    Name: string,
    Groups: {
        [string]: GroupConfig,
    },
    DefaultGroupKey: string?,
}

export type GroupConfig = {
    Classes: {ClassDescriptor},
    Limit: number,
    Default: boolean,
}

export type PlayerClassAssignment = {
    FactionId: string,
    GroupKey: string,
    ClassId: string,
}

export type Class = {
    ID: string,
    Items: {any}
}

export type InteractionController = {
    isOpen: Vide.source<boolean>,
    Initialize: (isOpen: Vide.source<boolean>) -> (),
    Destroy: () -> (),
}

return Types