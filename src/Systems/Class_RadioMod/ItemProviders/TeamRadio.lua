local Types = require("@game/ReplicatedStorage/Faction_Framework/Core/Types")
local Enums = require("@game/ReplicatedStorage/Faction_Framework/Core/Enums")

local RadioProvider: Types.ClassItemProvider<BuildArgs> = {
	ID = "Mod_Radio",
	AssignType = Enums.AssignType.PerPlayer,
}

export type BuildArgs = {
	frequency: string,
	isOperator: boolean,
}
export type ItemArgs = { type: "Mod_Radio" } & BuildArgs

function RadioProvider.Build(args: BuildArgs): ItemArgs
	return {
		type = RadioProvider.ID,
		frequency = args.frequency,
		isOperator = args.isOperator,
	}
end

function RadioProvider.Assign(player: Player, args: ItemArgs)
	-- stub
end

function RadioProvider.Unassign(player: Player, args: ItemArgs)
	-- stub
end

return RadioProvider
