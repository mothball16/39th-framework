local VideCharm = require("@game/ReplicatedStorage/Packages/vide-charm")
local Types = require("../Core/Types")
local State = require("../Core/State")
local GetPlayerSlice = require("./GetPlayerSlice")

local useSignal = VideCharm.useSignalState

export type PlayerSlice = {
	factionId: () -> string?,
	factionConfig: () -> Types.FactionConfig?,
	classCounts: () -> { [string]: number },
	classKey: () -> string?,
	variantId: () -> string?,
	classConfig: () -> Types.ClassConfig?,
	classEntries: () -> { Types.ClassConfig },
	variants: () -> { Types.VariantDescriptor },
}

return function(state: State.State, userId: string): PlayerSlice
	local slice = GetPlayerSlice(state, userId)

	return {
		factionId = useSignal(slice.factionId),
		factionConfig = useSignal(slice.factionConfig),
		classCounts = useSignal(slice.classCounts),
		classKey = useSignal(slice.classKey),
		variantId = useSignal(slice.variantId),
		classConfig = useSignal(slice.classConfig),
		classEntries = useSignal(slice.classEntries),
		variants = useSignal(slice.variants),
	}
end
