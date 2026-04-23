local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local CharmSync = require(Packages["charm-sync"])
local Maid = require(Packages.maid)
local Framework = ReplicatedStorage:WaitForChild("Class_Framework")
local Types = require(Framework:WaitForChild("Types"))

local ServerState = {}
ServerState.__index = ServerState

function ServerState.new(atoms: Types.Atoms, events: Types.Events)
	local self = setmetatable({}, ServerState)
	self.maid = Maid.new()
	self.atoms = atoms
	self.syncer = CharmSync.server({
		atoms = self.atoms,
		interval = 0,
		preserveHistory = false,
		autoSerialize = true,
	})
	self.maid:GiveTask(self.syncer:connect(function(player, ...)
		events.SyncState:FireClient(player, ...)
	end))

	self.maid:GiveTask(events.RequestState:Connect(function(player)
		self.syncer:hydrate(player)
	end))

	self.maid:GiveTask(self.syncer)
	return self
end

function ServerState:Destroy()
	self.maid:DoCleaning()
end

return ServerState
