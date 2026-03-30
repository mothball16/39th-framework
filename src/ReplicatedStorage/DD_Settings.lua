local config = {}

-- aesthetic stuff
config.placeholderImage = 18349410570 -- the placeholder image
config.defaultColor = Color3.fromRGB(248, 248, 248) -- user interface element colors
config.neutralColor = Color3.fromRGB(255, 255, 255) -- use for neutral elements or heads-up display items
config.healthColor = nil -- healthbar color if you want it to be different from default
config.negativeColor = Color3.fromRGB(179, 30, 30) -- negative color for UI elements
config.warningColor = Color3.fromRGB(255, 85, 0) -- warning color for UI elements
config.playerColor = Color3.fromRGB(255, 255, 127)
config.squadColor = Color3.fromRGB(0, 255, 0) -- used to represent squad stuff
config.teamColor = Color3.fromRGB(0, 100, 255) -- used to represent team stuff
config.monochrome = false -- recolor player-determined images? (flags, national icons etc.)

-- player settings
config.useAltIDs = false -- set player alt IDs? (see setAltID function in UCS_Server) e.g. if you have a clone group, call up someone's CT-number here
config.leaderboardKillStat = "K" -- DD_SPH: leaderboard stat customization for working with multiple different systems or leaderboards
config.leaderboardTKStat = "TK" -- adds teamkills to whichever stat your leaderboard uses to track Teamkills. If you want TKs to count as kills, set this to match the kill stat
config.leaderboardDeathStat = "D" -- DD_SPH: leaderboard stat customization for working with multiple different systems or leaderboards
config.maxHealth = 100 -- DD_SPH: Sets max health automatically

-- lobby info
config.lobbyTeam = "Choosing" -- what team do you want to be the lobby team?

-- team settings
config.Factions = -- At this time, a maximum of two factions are possible. Change the "Name" variable, not the actual name. Multiple factions will be supported in future versions.
	{
		["A"] =
		{
			["Name"] = "Coalition",
			["Color"] = Color3.fromRGB(51, 88, 130), -- what color is this faction typically
		},
		["B"] =
		{
			["Name"] = "Insurgency",
			["Color"] = Color3.fromRGB(151, 0, 0),
		}

	}

config.Teams = -- Place each team that you want to be able to score points here. Assign their faction based on what side you want them to be on.
	{
		["Evil Heroes"] =
		{
			["Faction"] = "A", -- What team is this faction under
			["LogoID"] = 128750731148083, -- what logo do you want shown next to your team
		},
		["Ambiguous Protagonists"] =
		{
			["Faction"] = "A", -- What team is this faction under
			--["LogoID"] = 1234, -- what logo do you want shown next to your team
		},
		["Good Villains"] =
		{
			["Faction"] = "B", -- What team is this faction under
			["LogoID"] = 115040978067156, -- what logo do you want shown next to your team
		}
	}

return config
