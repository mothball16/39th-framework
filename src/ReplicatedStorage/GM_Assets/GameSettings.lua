local config = {}
config.useSpearhead = true -- use Spearhead's BridgeNet module?

-- teamkill punishment
config.teamKillKick = true -- kick people if they teamkill? settings below
config.teamKillStreakThreshold = 50 -- kick people if they teamkill X amount of people in one lifetime?
config.teamKillTotalThreshold = 100 -- kick people if they teaamkill X amount of people overall?

-- round information
config.Endless = false -- Will rounds just keep initiating forever? Turn this on for games you don't plan to self-manage e.g. Murder Mystery or MECS
config.EndlessGameMode = "TDM" -- what round mode would you like endless rounds to default to?

-- lobby info
config.lobbyTeam = "AWAITING DEPLOYMENT" -- what team do you want to be the lobby team?
config.intermissionLength = 30 -- the length, in seconds, of an intermission
config.resetOnStart = true -- reset all players on game start?

-- group stuff
--config.groupRanks = true -- see the player's rank in a group?
-- ^^ Will be added in future versions ^^

-- whitelists
config.userAdminList = -- list of users you want to give game master permissions
	{
		"hollybe03",
		"Ankhea",
		"cookieoros",
		"Aimbo45",
		"Random_driver17",
		"goos3sd",
		"GalaxysQuery"
	}
config.GroupAdminList = false
config.Groups = -- list of groups where you want certain ranks to have game master permissions
	{
		["Dragoon's Den"] = -- the group where you want some ranks to have game master permissions
		{
			id = 34671030; -- the ID of your group (found in your group's URL e.g. https://www.roblox.com/communities/(YOUR ID))
			ranks = {69, 100, 200, 254, 255} -- the rankIDs of the ranks you want to have game master permissions
		};
	};

-- aesthetic stuff
config.defaultColor = Color3.fromRGB(235, 235, 235) -- user interface element colors
config.neutralColor = Color3.fromRGB(255, 255, 255) -- use for neutral elements or heads-up display items
config.negativeColor = Color3.fromRGB(179, 30, 30) -- negative color for UI elements
config.playerColor = Color3.fromRGB(255, 255, 127)
config.squadColor = Color3.fromRGB(157, 235, 164) -- used to represent squad stuff

config.Factions = -- At this time, a maximum of two factions are possible. Change the "Name" variable, not the actual name. Multiple factions will be supported in future versions.
	{
		["A"] =
		{
			["Name"] = "FEDERAL MARITIME DEFENSE FORCES",
			["Color"] = Color3.fromRGB(0, 32, 96), -- what color is this faction typically
		},
		["B"] =
		{
			["Name"] = "NOOBIC MARINE CORPS",
			["Color"] = Color3.fromRGB(86, 36, 36),
		}

	}

config.Teams = -- Place each team that you want to be able to score points here. Assign their faction based on what side you want them to be on.
	{
		["FEDERAL MARITIME DEFENSE FORCES"] =
		{
			["Faction"] = "A", -- What team is this faction under
			["LogoID"] = 1234, -- what logo do you want shown next to your team
		},
		["FSD"] =
		{
			["Faction"] = "A", -- What team is this faction under
			["LogoID"] = 1234, -- what logo do you want shown next to your team
		},
		["NOOBIC MARINE CORPS"] =
		{
			["Faction"] = "B", -- What team is this faction under
			["LogoID"] = 1234, -- what logo do you want shown next to your team
		}
	}

config.version = "v1.01"
return config
