local Types = require("./Types")
local Item = require("./Item")
local Mocks = {}

function Mocks.Player(playerId: number)
	return {
		UserId = playerId,
	}
end

function Mocks.VariantConfig(variantId: string)
	return {
		ID = variantId,
		Items = {
			Item.test({
				name = `{variantId}_Test`,
			}),
		},
	}
end

function Mocks.FactionConfig(factionId: string): Types.FactionConfig
	return {
		ID = factionId,
		Name = "United States Marine Corps",
		Classes = {
			Rifleman = {
				Variants = {
					{
						Id = "RiflemanA",
						Name = "Rifleman",
						Description = "Rifleman uno\n\n\n",
					},
					{
						Id = "RiflemanB",
						Name = "Rifleman Alt",
						Description = "Rifleman dos\n\n\n",
					},
					{
						Id = "RiflemanZ",
						Name = "Rifleman Super Hacker",
						Description = "Rifleman Super Hacker\n\n\n",
						AccessCheck = function(player: Player)
							return false
						end,
					},
				},
				Limit = math.huge,
				Default = true,
			},
			Engineer = {
				Variants = {
					{
						Id = "EngineerA",
						Name = "Engineer",
						Description = "The only\n\n\n",
					},
				},
				Limit = 2,
				Default = false,
			},
			Marksman = {
				Variants = {
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
