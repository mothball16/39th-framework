local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local CharmSync = require(Packages["charm-sync"])
local Maid = require(Packages.maid)

local ServerSyncer = {}
ServerSyncer.__index = ServerSyncer

function ServerSyncer.new(state, events)
	local self = setmetatable({}, ServerSyncer)
	self.maid = Maid.new()
	self.syncer = CharmSync.server({
		atoms = state,
		interval = 0,
		preserveHistory = false,
		autoSerialize = true,
	})
	self.maid:GiveTask(self.syncer:connect(function(player, ...)
		events.SyncState:FireClient(player, ...)
	end))

	self.maid:GiveTask(events.RequestState.OnServerEvent:Connect(function(player)
		self.syncer:hydrate(player)
	end))

	return self
end

function ServerSyncer:Destroy()
	self.maid:DoCleaning()
end

return ServerSyncer
