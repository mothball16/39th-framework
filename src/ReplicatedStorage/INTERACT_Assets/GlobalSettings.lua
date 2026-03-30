--[[       
INTERACTIVE SYSTEM
Global Settings
1.4.3

by Jarr (@SrJarr) aka jarr__
RELEASED FOR FREE - DRAGOON'S DEN
--]]

local config = {}

--// Version & Info
config.prefix = "«-INTSYS-»"
config.version = "1.4.3"
config.credits = {"Jarr", "VanguardCobalt"} --Gamer_Okami for the original okami chassis

config.AutoTeamEnabled = false --Use this for auto-team.
config.AutoTeamTools = true --Like starterPack but for teams. Each player will be given the tools in their Team!
config.Groups =
	{
		["Test"] =
		{
			["GroupName"] = "Example Team",
			["GroupID"] = 1,
			["GroupRank"] = {2,256},
		},
	}

return config
