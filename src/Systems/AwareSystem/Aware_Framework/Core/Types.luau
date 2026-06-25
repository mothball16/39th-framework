local Types = {}

export type GameSettings = {
    -- injectable function to get the team value of a player - used so non-team based systems can still use this
    GetTeamValue: (player1: Player) -> string,
}

return Types