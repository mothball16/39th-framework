--!strict
local Charm = require("@game/ReplicatedStorage/Packages/Charm")
local VideCharm = require("@game/ReplicatedStorage/Packages/vide-charm")
local Maid = require("@game/ReplicatedStorage/Packages/maid")

local useAtom = VideCharm.useAtom
local useSignal = VideCharm.useSignalState

local Types = require("./Types")

local State = {}
State.__index = State

type ClassCountByFaction = { [string]: { [string]: number } }

type self = {
	configByFactionId: Charm.Atom<{ [string]: Types.FactionConfig }>,
	playerAssignmentByUserId: Charm.Atom<{ [string]: Types.PlayerAssignment }>,
	getClassCountByFaction: Charm.Getter<ClassCountByFaction>,

	maid: Maid.Maid,
}
export type State = typeof(setmetatable({} :: self, State))

function State.new(): State
	local self = setmetatable({} :: self, State)
	self.maid = Maid.new()
	self.configByFactionId = Charm.atom({})
	self.playerAssignmentByUserId = Charm.atom({})
	self.getClassCountByFaction = self:SetupClassCounts()
	return self
end

-- safely creates a getter for class counts. encapsulates logic for setting this signal within the effect scope
function State.SetupClassCounts(self: State): Charm.Getter<ClassCountByFaction>
	
	local getClassCountByFaction, setClassCountByFaction = Charm.signal({} :: ClassCountByFaction)

	self.maid:GiveTask(Charm.effectScope(function()
		--CREATE/DESTROY class counts whenever a faction config is added/removed
		Charm.observe(self.configByFactionId, function(factionConfig: Types.FactionConfig, key: string)
			setClassCountByFaction(function(state)
				state = table.clone(state)
				state[key] = {} :: { [string]: number }
				for classKey, _ in pairs(factionConfig.Classes) do
					state[key][classKey] = 0
				end
				return state
			end)

			return function()
				setClassCountByFaction(function(state)
					local nextState = table.clone(state)
					nextState[key] = nil :: any
					return nextState
				end)
			end
		end)

		-- imperative logic for O(1) UPDATE (this is a completely unnecessary micro-optimization loool)
		Charm.observe(self.playerAssignmentByUserId, function(value: Types.PlayerAssignment, key: string)
			local currentClassKey = Charm.computed(function()
				return self.playerAssignmentByUserId()[key].ClassKey
			end)
			local currentFactionId = Charm.computed(function()
				return self.playerAssignmentByUserId()[key].FactionId
			end)
			
			local undoLastIncrement: (() -> ())? = nil
			local function incrementClassCount(factionId: string?, classKey: string?, count: number): (() -> ())?
				-- if the faction or class key isn't set, nothing can be incremented
				if not factionId or not classKey then
					return nil
				end

				-- if the faction doesn't exist, nothing can be incremented
				local curFactionClassCounts = Charm.untracked(getClassCountByFaction)[factionId]
				if not curFactionClassCounts then
					return nil
				end

				-- if the class count doesn't exist, nothing can be incremented
				local classCount: number? = curFactionClassCounts[classKey]
				if classCount == nil then
					warn(`class count not found for class key {classKey} in faction {factionId}`)
					return nil
				end
				
				setClassCountByFaction(function(state)
					state = table.clone(state)
					local nextFactionCounts = table.clone(state[factionId])
					nextFactionCounts[classKey] = classCount + count
					state[factionId] = nextFactionCounts
					return state
				end)

				-- return the undo: if this becomes invalid later, then we can assume the faction was removed
				return function()
					incrementClassCount(factionId, classKey, -count)
				end
			end

			-- this will run whenever the player faction/class changes
			Charm.effect(function()
				Charm.batch(function()
					if undoLastIncrement then
						undoLastIncrement()
						undoLastIncrement = nil
					end
					undoLastIncrement = incrementClassCount(currentFactionId(), currentClassKey(), 1)
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
	end))

	return getClassCountByFaction
end


function State:AsVideSources()
	return {
		configByFactionId = useAtom(self.configByFactionId),
		playerAssignmentByUserId = useAtom(self.playerAssignmentByUserId),
		getClassCountByFaction = useSignal(self.getClassCountByFaction),
	}
end

function State:Destroy()
	self.maid:DoCleaning()
end


return State
