local Atoms = require(script.Parent.Atoms)
local Events = require(script.Parent.Events)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Charm = require(Packages.Charm)

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

export type ISettings = {
    ItemTypePaths: {
        [string]: Folder,
    },
}

export type IFaction = {
    Identifier: string,
    ItemProviders: {
        ItemType: string,
        Classes: {
            [string]: {Class: IClass, Limit: number}
        }
    }
}

export type IClass = {
    Identifier: string,
    Items: {
        -- key should align with the identifier of a module implementing IClassItem
        -- this will be resolved within ClassEquipper
        [string]: {any}
    }
}

return {}