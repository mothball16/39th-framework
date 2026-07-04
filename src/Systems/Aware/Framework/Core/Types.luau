--!strict
local Charm = require("@game/ReplicatedStorage/Packages/Charm")
local Types = {}

export type GetTeamValue = (player1: Player) -> string?

export type GameSettings = {
    -- whether to replicate the ping to the player themselves - this is only for debugging
    ReplicateToSelf: boolean,
    -- injectable function to get the team value of a player - used so non-team based systems can still use this
    GetTeamValue: GetTeamValue,
    -- imageId for ping
    PingImageId: string,
    -- max distance for pinging
    PingMaxDistance: number,
    -- interval at which to update the team state
    TeamUpdateInterval: number,
}

-- properties for the visual display of a ping tag
export type PingTagProps = {
    imageId: string,
    name: string,
}

-- information stored within the state for a ping
export type PingInfo = PingTagProps & {
    position: Vector3,
    owner: Player,
}

export type OwnedValues = {
    Team: string?,
    Pings: { [string]: PingInfo },
}


export type State = {
    valuesByPlayer: Charm.Atom<{ [string]: OwnedValues }>,
    valuesByTeam: Charm.Getter<{ [string]: { [string]: OwnedValues } }>,
}

return Types