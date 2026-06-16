--!strict
local Charm = require("@game/ReplicatedStorage/Packages/Charm")
local VideCharm = require("@game/ReplicatedStorage/Packages/vide-charm")
local useAtom = VideCharm.useAtom
local useSignal = VideCharm.useSignalState

local Types = require("./Types")

local State = {}
State.__index = State

type self = {
	configByFactionId: Charm.Atom<{ [string]: Types.FactionConfig }>,
	playerAssignmentByUserId: Charm.Atom<{ [string]: Types.PlayerClassAssignment }>,
	groupCountByFaction: Charm.Getter<{ [string]: { [string]: number } }>,
}
export type State = typeof(setmetatable({} :: self, State))

function State.new(): State
	local getGroupCountByFaction, setGroupCountByFaction = Charm.signal({} :: { [string]: { [string]: number } })
	local self = setmetatable(
		{
			configByFactionId = Charm.atom({}),
			playerAssignmentByUserId = Charm.atom({}),

			-- don't sync
			getGroupCountByFaction = getGroupCountByFaction,
		} :: self,
		State
	)

	Charm.effectScope(function()
		-- create/destroy group counts whenever a faction config is added/removed
		Charm.observe(self.configByFactionId, function(factionConfig: Types.FactionConfig, key: string)
			setGroupCountByFaction(function(state)
				state = table.clone(state)
				state[key] = {} :: { [string]: number }
				for groupKey, _ in pairs(factionConfig.Groups) do
					state[key][groupKey] = 0
				end
				return state
			end)

			return function()
				setGroupCountByFaction(function(state)
					local nextState = table.clone(state)
					nextState[key] = nil :: any
					return nextState
				end)
			end
		end)

		-- imperative logic for O(1) updates (this is a completely unnecessary micro-optimization loool)
		Charm.observe(self.playerAssignmentByUserId, function(value: Types.PlayerClassAssignment, key: string)
			local currentGroupKey = Charm.computed(function()
				return self.playerAssignmentByUserId()[key].GroupKey
			end)
			local currentFactionId = Charm.computed(function()
				return self.playerAssignmentByUserId()[key].FactionId
			end)
			
			local undoLastIncrement: (() -> ())? = nil
			local function incrementGroupCount(factionId: string?, groupKey: string?, count: number): (() -> ())?
				-- if the faction or group key isn't set, nothing can be incremented
				if not factionId or not groupKey then
					return nil
				end

				-- if the faction doesn't exist, nothing can be incremented
				local curFactionGroupCounts = Charm.untracked(getGroupCountByFaction)[factionId]
				if not curFactionGroupCounts then
					return nil
				end

				-- if the group count doesn't exist, nothing can be incremented
				local groupCount: number? = curFactionGroupCounts[groupKey]
				if groupCount == nil then
					warn(`group count not found for group key {groupKey} in faction {factionId}`)
					return nil
				end
				
				setGroupCountByFaction(function(state)
					state = table.clone(state)
					local nextFactionCounts = table.clone(state[factionId])
					nextFactionCounts[groupKey] = groupCount + count
					state[factionId] = nextFactionCounts
					return state
				end)

				print("group count incremented", factionId, groupKey, count, groupCount + count)

				-- return the undo: if this becomes invalid later, then we can assume the faction was removed
				return function()
					incrementGroupCount(factionId, groupKey, -count)
				end
			end

			-- this will run whenever the player faction/group changes
			Charm.effect(function()
				Charm.batch(function()
					if undoLastIncrement then
						undoLastIncrement()
						undoLastIncrement = nil
					end
					undoLastIncrement = incrementGroupCount(currentFactionId(), currentGroupKey(), 1)
				end)
			end)
			
			-- this will run on player leave
			return function()
				if undoLastIncrement then
					undoLastIncrement()
					undoLastIncrement = nil
				end
			end
		end)
	end)
	return self
end

function State:AsVideSources()
	return {
		configByFactionId = useAtom(self.configByFactionId),
		playerAssignmentByUserId = useAtom(self.playerAssignmentByUserId),
		getGroupCountByFaction = useSignal(self.getGroupCountByFaction),
	}
end

function State:Destroy()
	-- i think atoms automatically cleanup?
end


return State
