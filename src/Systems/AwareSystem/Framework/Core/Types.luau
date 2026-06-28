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
}

export type PingTagProps = {
    imageId: string,
    name: string,
}

return Types