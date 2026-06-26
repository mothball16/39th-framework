local Types = {}

export type GameSettings = {
    -- whether to replicate the ping to the player themselves - this is only for debugging
    ReplicateToSelf: boolean,
    -- injectable function to get the team value of a player - used so non-team based systems can still use this
    GetTeamValue: (player1: Player) -> string,
}

return Types