local Types = require("./Types")
local Mocks = {}



function Mocks.Player(playerId: string)
    return {
        UserId = playerId,
    }
end

function Mocks.ClassConfig(classId: string)
    return {
        ID = classId,
        Items = {
            itemType = "Test",
            itemName = `{classId}_Test`,
        }
    }
end

function Mocks.FactionConfig(factionId: string)
    return {
        ID = factionId,
        Name = "United States Marine Corps",
        Classes = {
            Rifleman = {
                ClassIDs = {
                    {
                        Id = "RiflemanA",
                        Name = "Rifleman",
                        Description = "Rifleman uno\n\n\n",
                    },
                    {
                        Id = "RiflemanB",
                        Name = "Rifleman Alt",
                        Description = "Rifleman dos\n\n\n",
                    }
                },
                Limit = 10,
                Default = true,
            },
            Engineer = {
                ClassIDs = {
                    {
                        Id = "EngineerA",
                        Name = "Engineer",
                        Description = "The only\n\n\n",
                    }
                },
                Limit = 2,
                Default = false,
            },
            Marksman = {
                ClassIDs = {
                    {
                        Id = "MarksmanA",
                        Name = "Marksman",
                        Description = "The best\n\n\n",
                    },
                    {
                        Id = "MarksmanB",
                        Name = "Marksman Alt",
                        Description = "The best dos\n\n\n",
                    },
                },
                Limit = 1,
                Default = false,
            },
        },
    } :: Types.FactionConfig
end

return Mocks