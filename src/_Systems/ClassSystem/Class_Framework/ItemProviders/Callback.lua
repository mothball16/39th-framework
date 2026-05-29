local Types = require("../Core/Types")
local Enums = require("../Core/Enums")

local CallbackProvider: Types.ClassItemProvider<BuildArgs> = {
	ID = "Callback",
	AssignType = Enums.AssignType.PerPlayer,
}

export type CallbackFn = (player: Player, args: ItemArgs) -> ()
export type BuildArgs = {
	name: string?,
	onAssign: CallbackFn?,
	onUnassign: CallbackFn?,
}
export type ItemArgs = { type: "Callback" } & BuildArgs

function CallbackProvider.Build(args: BuildArgs): ItemArgs
	return {
		type = CallbackProvider.ID,
		name = args.name,
		onAssign = args.onAssign,
		onUnassign = args.onUnassign,
	}
end

function CallbackProvider.Assign(player: Player, args: ItemArgs)
	if args.onAssign then
		args.onAssign(player, args)
	end
end

function CallbackProvider.Unassign(player: Player, args: ItemArgs)
	if args.onUnassign then
		args.onUnassign(player, args)
	end
end

return CallbackProvider
