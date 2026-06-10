return {
    ApplyClassMode = {
        -- changes to class will cause class to be unapplied until interaction is complete
        AfterInteraction = "AfterInteraction",
        -- class will be applied immediately on assignment
        Immediate = "Immediate",
        -- classes will not be auto-applied, needs explicit call
        Explicit = "Explicit",
    },

    AfterTeamChangeBehavior = {
        -- nothing happens
        None = "None",
        -- assign the class items immediately
        Assign = "Assign",
    },

    AssignType = {
        -- assign method will hook up to the character of the player and whenever the character spawns
        PerCharacter = "PerCharacter",
        -- assign method will hook up to the player
        PerPlayer = "PerPlayer",
    },

    Faction = {
        AutoFactionAttribute = "AutoFaction",
    },

    KeyAttributes = {
        ItemProvider = "ItemProviderID",
        ItemName = "ItemName"
    }
}