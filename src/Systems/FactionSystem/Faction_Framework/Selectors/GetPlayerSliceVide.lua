local VideCharm = require("@game/ReplicatedStorage/Packages/vide-charm")
local Types = require("../Core/Types")
local State = require("../Core/State")
local GetPlayerSlice = require("./GetPlayerSlice")

local useSignal = VideCharm.useSignalState

export type PlayerSlice = {
	factionId: () -> string?,
	factionConfig: () -> Types.FactionConfig?,
	groupCounts: () -> { [string]: number },
	groupKey: () -> string?,
	classId: () -> string?,
	groupConfig: () -> Types.GroupConfig?,
	groupEntries: () -> { Types.GroupConfig },
	classes: () -> { Types.ClassDescriptor },
}

return function(state: State.State, userId: string): PlayerSlice
	local slice = GetPlayerSlice(state, userId)

	return {
		factionId = useSignal(slice.factionId),
		factionConfig = useSignal(slice.factionConfig),
		groupCounts = useSignal(slice.groupCounts),
		groupKey = useSignal(slice.groupKey),
		classId = useSignal(slice.classId),
		groupConfig = useSignal(slice.groupConfig),
		groupEntries = useSignal(slice.groupEntries),
		classes = useSignal(slice.classes),
	}
end
