local spawnLimits = {}

spawnLimits.Settings = 
	{
		CollisionCheck = true, --Should we check if the spawning area is empty before allowing spawn?
		CollisionExclusive = true, --Set to true if you only want the things parented to "Vehicles" to block the spawners.

		ClearArea = true, --Should the spawner remove any vehicles found in the area before spawning one?
		ClearTags = {"Okami_Chassis", "Okami_Trailer", "Dragoon_Vehicle", "Dragoon_Compat"}, --Objects with these tags can be deleted.
		
		AutoClean = 180, --Despawn unused vehicles every X seconds. Set to nil to disable automatic cleanup.
		
		RegenProximity = 25, --Prevent vehicles with nearby players from being despawned. Set to nil to disable this protection
		RegenProof = 5, --Prevents vehicles from being despawned before the set amount of time. Set to nil to disable this protection.

		TeleportPlayer = false --Should we attempt to TP the player into a driver seat?
		--[[ ! WARNING !: TeleportPlayer function might break vehicles that work with EntryScript AND also have the JumpPreventionSpeed setting on. You need the latest EntryScript version for this!]]--
	} 

spawnLimits.SpawnPools = --Group vehicles together that are meant to share a spawn limit
	{
		["Main Battle Tank"] = 3,
		["Main Battle Tank 2"] = 1,
		["Main Battle Tank WN"] = 3, 
		["Light Tank"] = 1,
		["Light Tank WN"] = 3,
		["Infantry Fighting Vehicle"] = 3,
		["Infantry Fighting Vehicle WN"] = 4,
		["Armored Personnel Carrier"] = 3,
		["Armored Personnel Carrier WN"] = 4,
		["MRAP"] = 15,
		["Light Utility"] = 50,
		["Artillery"] = 10,
		["Aircraft"] = 2,
		["Light Support Tank"] = 1,
		["Tank Destroyer"] = 1,
		["Tank Destroyer WN"] = 2,
		["Utility Helicopter"] = 2,
		["Utility Helicopter EN"] = 2,

	}

spawnLimits.Info = {
	--Main Battle Tanks
	["VT-2A1"] = --Actual model name
		{
			DisplayName = [[Versatile Tank - 2 Alteration 1]], --For display in the description
			ShortName = "VT-2A1", --For display in the list
			SpawnLimit = "Main Battle Tank", --Set to a number or to the name of a shared spawn pool.
			ImageID = 88913724228806,
			Description = "The Versatile Tank - 2 Alteration 1, the primary MBT utilized by the Noobic Stratocracy."
		},
	["RM-3-U4"] = --Actual model name
		{
			DisplayName = [[Raider Medium - 3 - U4]], --For display in the description
			ShortName = "VT-2A1", --For display in the list
			SpawnLimit = "Main Battle Tank WN", --Set to a number or to the name of a shared spawn pool.
			ImageID = 88913724228806,
			Description = "An advanced MBT utilized by West Noobia, the best tank Bloxia will provide because they are literally Israel."
		},
	["LST-1p"] = --Actual model name
		{
			DisplayName = [[Light Support Tank - 1 (prototype)]], --For display in the description
			ShortName = "LST-1p", --For display in the list
			SpawnLimit = "Light Support Tank", --Set to a number or to the name of a shared spawn pool.
			ImageID = 88913724228806,
			Description = "TBD."
		},
	["VT-6"] = --Actual model name
		{
			DisplayName = [[Versatile Tank - 6 "Paladin"]], --For display in the description
			ShortName = "VT-6", --For display in the list
			SpawnLimit = "Main Battle Tank 2", --Set to a number or to the name of a shared spawn pool.
			ImageID = 88913724228806,
			Description = "The most advanced and capable tank of the Noobic Stratocracy: the VT-6 Monarch. This specific tank is the Paladin, under the command of SSGT raandoomgamer."
		},

	--Light Tanks
	["ARV-5"] = --Actual model name
		{
			DisplayName = [[Armored Reconnaissance Vehicle - 5]], --For display in the description
			ShortName = "ARV-5", --For display in the list
			SpawnLimit = "Light Tank", --Set to a number or to the name of a shared spawn pool.
			ImageID = 85774026110268,
			Description = "A wheeled recon tank fitted with a 90mm cannon, great for ratting."
		},
	["RL-6"] = --Actual model name
		{
			DisplayName = [[Raider Light - 6]], --For display in the description
			ShortName = "RL-6", --For display in the list
			SpawnLimit = "Light Tank WN", --Set to a number or to the name of a shared spawn pool.
			ImageID = 85774026110268,
			Description = "A light tank resembling the M41 Walker Bulldog, utilized by West Noobia."
		},
	--Infantry Fighting Vehicles
	["ICV-1"] = --Actual model name
		{
			DisplayName = [[Infantry Carrier Vehicle - 1]], --For display in the description
			ShortName = "ICV-1", --For display in the list
			SpawnLimit = "Infantry Fighting Vehicle", --Set to a number or to the name of a shared spawn pool.
			ImageID = 138523023660710,
			Description = "The primary infantry fighting & carrier vehicle of the Noobic Stratocracy, equipped with a 30mm autocannon."
		},
	--Armored Personnel Carriers
	["LVT-A2"] = --Actual model name
		{
			DisplayName = [[Landing Vehicle, Tracked A2]], --For display in the description
			ShortName = "LVT-A2", --For display in the list
			SpawnLimit = "MRAP", --Set to a number or to the name of a shared spawn pool.
			ImageID = 86120898806850,
			Description = "A tracked landing vehicle used by the Noobic Marine Corps."

		},

	["M52 APC"] = --Actual model name
		{
			DisplayName = [[Model 52 Armored Personnel Carrier]], --For display in the description
			ShortName = "M52 APC", --For display in the list
			SpawnLimit = "MRAP", --Set to a number or to the name of a shared spawn pool.
			ImageID = 86120898806850,
			Description = "A tracked armored troop carrier vehicle used by the Federal Republic of Noobia. Armed with a .50 caliber machinegun."

		},

	["M52 TD"] = --Actual model name
		{
			DisplayName = [[Model 52 Armored Personnel Carrier]], --For display in the description
			ShortName = "M52 APC", --For display in the list
			SpawnLimit = "Tank Destroyer WN", --Set to a number or to the name of a shared spawn pool.
			ImageID = 86120898806850,
			Description = "A tracked armored troop carrier vehicle used by the Federal Republic of Noobia. Armed with a .50 caliber machinegun."

		},

	--MRAPS
	["HTV-2"] = --Actual model name
		{
			DisplayName = [[Heavy Transport Vehicle - 2]], --For display in the description
			ShortName = "HTV-2", --For display in the list
			SpawnLimit = "MRAP", --Set to a number or to the name of a shared spawn pool.
			ImageID = 124708380472615,
			Description = "The primary heavy utility vehicle in service within the Noobic Stratocracy. Used to carry heavy loads of supplies, fuel or armament."
		},
	["LRV-2"] = --Actual model name
		{
			DisplayName = [[Light Reconnaissance Vehicle - 2]], --For display in the description
			ShortName = "LRV-2", --For display in the list
			SpawnLimit = "Infantry Fighting Vehicle", --Set to a number or to the name of a shared spawn pool.
			ImageID = 124708380472615,
			Description = "An armored car built for speed and ratting utilized by the Noobic Stratocracy."
		},
	["WN Armored Car"] = --Actual model name
		{
			DisplayName = [[Raider Armored Car]], --For display in the description
			ShortName = "WN Armored Car", --For display in the list
			SpawnLimit = "Infantry Fighting Vehicle WN", --Set to a number or to the name of a shared spawn pool.
			ImageID = 124708380472615,
			Description = "An armored car built for speed and ratting utilized by West Noobia."
		},
	--Light Utility
	["Lee's Light Utility Vehicle"] = --Actual model name
		{
			DisplayName = [[Lee's Light Utility Vehicle]], --For display in the description
			ShortName = "LLUV", --For display in the list
			SpawnLimit = "Light Utility", --Set to a number or to the name of a shared spawn pool.
			ImageID = 124708380472615,
			Description = "The primary light utility vehicle in service in the Noobic Stratocracy."
		},
	["LLRV"] = --Actual model name
		{
			DisplayName = [[Lee's Light Raider Vehicle]], --For display in the description
			ShortName = "LLRV", --For display in the list
			SpawnLimit = "Light Utility", --Set to a number or to the name of a shared spawn pool.
			ImageID = 124708380472615,
			Description = "The primary light utility vehicle in service in the Federal Republic of Noobia."
		},
	["Maintenance LLUV"] = --Actual model name
		{
			DisplayName = [[Maintenance Lee's Light Utility Vehicle]], --For display in the description
			ShortName = "Maintenance LLUV", --For display in the list
			SpawnLimit = "Light Utility", --Set to a number or to the name of a shared spawn pool.
			ImageID = 124708380472615,
			Description = "The primary light utility vehicle in service in the Noobic Stratocracy. Fitted with warning lights and a siren for alerting personnel about maintenance operations."
		},
	["Maintenance LLUV + Supply Bed"] = --Actual model name
		{
			DisplayName = [[Maintenance Lee's Light Utility Vehicle + Supply Bed]], --For display in the description
			ShortName = "Maintenance LLUV", --For display in the list
			SpawnLimit = "Light Utility", --Set to a number or to the name of a shared spawn pool.
			ImageID = 124708380472615,
			Description = "The primary light utility vehicle in service in the Noobic Stratocracy. Fitted with warning lights and a siren for alerting personnel about maintenance operations, also loaded with supplies."
		},
	["MTV-2"] = --Actual model name
		{
			DisplayName = [[Multirole Transport Vehicle - 2]], --For display in the description
			ShortName = "MTV-2", --For display in the list
			SpawnLimit = "Light Utility", --Set to a number or to the name of a shared spawn pool.
			ImageID = 124708380472615,
			Description = "The primary infantry transport and supply carrier in service in the Noobic Stratocracy. A versatile vehicle, able to fulfill many purposes."
		},
	["MTV-2 Cannon"] = --Actual model name
		{
			DisplayName = [[Multirole Transport Vehicle - 2]], --For display in the description
			ShortName = "MTV-2 Cannon", --For display in the list
			SpawnLimit = "Tank Destroyer", --Set to a number or to the name of a shared spawn pool.
			ImageID = 124708380472615,
			Description = "The primary infantry transport and supply carrier in service in the Noobic Stratocracy. Fitted with a 90mm cannon for anti-tank purposes."
		},
	["M41 Cannon"] = --Actual model name
		{
			DisplayName = [[Multirole Transport Vehicle - 2]], --For display in the description
			ShortName = "MTV-2 Cannon", --For display in the list
			SpawnLimit = "Tank Destroyer WN", --Set to a number or to the name of a shared spawn pool.
			ImageID = 124708380472615,
			Description = "An old but reliable truck utilized by the Federal Republic of Noobia. Fitted with a 90mm cannon for anti-tank purposes."
		},
	["M41 Utility"] = --Actual model name
		{
			DisplayName = [[M41 Utility Truck]], --For display in the description
			ShortName = "M41 Utility", --For display in the list
			SpawnLimit = "Light Utility", --Set to a number or to the name of a shared spawn pool.
			ImageID = 124708380472615,
			Description = "An old but reliable truck utilized by the Noobic Stratocracy."
		},
	["M41 Utility (WN)"] = --Actual model name
		{
			DisplayName = [[M41 Utility Truck WN]], --For display in the description
			ShortName = "M41 Utility", --For display in the list
			SpawnLimit = "Light Utility", --Set to a number or to the name of a shared spawn pool.
			ImageID = 124708380472615,
			Description = "An old but reliable truck utilized by the Federal Republic of Noobia."
		},
	--Artillery
	["B59 TAURO Artillery"] = --Actual model name
		{
			DisplayName = [[B59 TAURO Field Howitzer]], --For display in the description
			ShortName = "B59 TAURO Arty", --For display in the list
			SpawnLimit = "Artillery",
			ImageID = 137040344586498,
			Description = "You can be sure that bringing this to the battlefield will make quick work of any fortifications or armor formations. Just make sure you're not spotted before you begin firing!"
		},

	--Helicopters
	["MH-60 Blackhawk"] = --Actual model name
		{
			DisplayName = [[MH-60 Blackhawk]], --For display in the description
			ShortName = "MH-60 Blackhawk", --For display in the list
			SpawnLimit = "Aircraft", --Set to a number or to the name of a shared spawn pool.
			ImageID = 17329922783,
			Description = "SKYTech RotorLite helicopter with DTS compatibility and crash system."
		},

	["MH-60 Blackhawk (Minigun)"] = --Actual model name
		{
			DisplayName = [[MH-60 Blackhawk (Minigun)]], --For display in the description
			ShortName = "MH-60 Blackhawk (Minigun)", --For display in the list
			SpawnLimit = "Aircraft", --Set to a number or to the name of a shared spawn pool.
			ImageID = 17329922783,
			Description = "SKYTech RotorLite helicopter with DTS compatibility and crash system. Armed with dual miniguns."
		},

	["UH-3T"] = --Actual model name
		{
			DisplayName = [[UTILITY HELICOPTER 3 (TRANSPORT)]], --For display in the description
			ShortName = "UH-3T", --For display in the list
			SpawnLimit = "Utility Helicopter", --Set to a number or to the name of a shared spawn pool.
			ImageID = 17329922783,
			Description = "SKYTech RotorLite helicopter with DTS compatibility and crash system."
		},
	
	["H-34 NMC (DTSSKYTECH)"] = --Actual model name
		{
			DisplayName = [[H-34 NMC]], --For display in the description
			ShortName = "H-34", --For display in the list
			SpawnLimit = "Utility Helicopter EN", --Set to a number or to the name of a shared spawn pool.
			ImageID = 17329922783,
			Description = "SKYTech RotorLite helicopter with DTS compatibility and crash system."
		},

	--Misc
	["Fuel Trailer"] = --Actual model name
		{
			DisplayName = [[Fuel Trailer]], --For display in the description
			ShortName = "Fuel Trailer", --For display in the list
			SpawnLimit = 2, --Set to a number or to the name of a shared spawn pool.
			ImageID = 112836448179581,
			Description = "You can never carry too much fuel. Tow this with a truck or a big car."
		}
}

return spawnLimits
