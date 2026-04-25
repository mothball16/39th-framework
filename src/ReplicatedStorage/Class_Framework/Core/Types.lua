local Events = require(script.Parent.Events)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Charm = require(Packages.Charm)

local Types = {}

export type Events = typeof(Events)

export type IClassItemProvider = {
    -- identifier for item type within configurations
    ID: string,
    AssignType: string?,
    -- runs when the class containing the item is assigned to a player
    Assign: (player: Player, itemArgs: any) -> (),
    -- runs when the class containing the item is unassigned from a player
    Unassign: (player: Player, itemArgs: any) -> ()
}

export type ISettings = {
    ItemTypePaths: {
        [string]: Folder,
    },
}

export type IFactionConfig = {
    ID: string,
    Classes: {
        [string]: {ClassID: string, Limit: number, Default: boolean}
    },
}

export type IFactionState = {
    Members: {
        [string]: {
            Class: string
        }
    }
}

export type IFaction = {
    Config: IFactionConfig,
    State: IFactionState,
}

export type IClass = {
    ID: string,
    Items: {any}
}

return Types